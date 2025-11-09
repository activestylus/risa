# frozen_string_literal: true
require 'forwardable'

module Risa
  class Query
    include Enumerable
    extend Forwardable

    def_delegators :results, :each, :map, :select, :reject, :[], :size, :length,
                   :empty?, :any?, :all?, :to_a, :inspect

    def initialize(model_name, data, scopes, relations, conditions: [], order_field: nil, order_desc: false, limit_count: nil, offset_count: nil)
      @model_name = model_name
      @data = data
      @scopes = scopes
      @relations = relations
      @conditions = conditions
      @order_field = order_field
      @order_desc = order_desc
      @limit_count = limit_count
      @offset_count = offset_count
      @_results = nil
      
      @scopes.each do |scope_name, scope_lambda|
        define_singleton_method(scope_name) do |*args|
          begin
            instance_exec(*args, &scope_lambda)
          rescue => e
            raise Risa::ScopeError, "Error in scope :#{scope_name} for model :#{@model_name}: #{e.message}\n  #{e.backtrace&.first}"
          end
        end
      end
    end
    
def where(condition_hash = nil, &block)
  if block
    sub_query = self.class.new(@model_name, @data, @scopes, @relations)
    result_query = block.call(sub_query)
    sub_conditions = result_query.instance_variable_get(:@conditions)
    
    Query.new(@model_name, @data, @scopes, @relations,
             conditions: @conditions + [[:and_block, sub_conditions]],
             order_field: @order_field,
             order_desc: @order_desc,
             limit_count: @limit_count,
             offset_count: @offset_count)
  elsif condition_hash
    Query.new(@model_name, @data, @scopes, @relations,
             conditions: @conditions + [condition_hash],
             order_field: @order_field,
             order_desc: @order_desc,
             limit_count: @limit_count,
             offset_count: @offset_count)
  else
    self
  end
end

def or_where(condition_hash = nil, &block)
  if block
    sub_query = self.class.new(@model_name, @data, @scopes, @relations)
    result_query = block.call(sub_query)
    sub_conditions = result_query.instance_variable_get(:@conditions)
    
    Query.new(@model_name, @data, @scopes, @relations,
             conditions: @conditions + [[:or_block, sub_conditions]],
             order_field: @order_field,
             order_desc: @order_desc,
             limit_count: @limit_count,
             offset_count: @offset_count)
  elsif condition_hash
    Query.new(@model_name, @data, @scopes, @relations,
             conditions: @conditions + [[:or, condition_hash]],
             order_field: @order_field,
             order_desc: @order_desc,
             limit_count: @limit_count,
             offset_count: @offset_count)
  else
    self
  end
end
    
    def order(field, desc: false)
      Query.new(@model_name, @data, @scopes, @relations,
               conditions: @conditions,
               order_field: field,
               order_desc: desc,
               limit_count: @limit_count,
               offset_count: @offset_count)
    end
    
    def limit(count)
      Query.new(@model_name, @data, @scopes, @relations,
               conditions: @conditions,
               order_field: @order_field,
               order_desc: @order_desc,
               limit_count: count,
               offset_count: @offset_count)
    end
    
    def offset(count)
      Query.new(@model_name, @data, @scopes, @relations,
               conditions: @conditions,
               order_field: @order_field,
               order_desc: @order_desc,
               limit_count: @limit_count,
               offset_count: count)
    end
    
    def all
      results
    end
    
    def first
      raw_first = apply_filters.first
      raw_first ? wrap_instance(raw_first) : nil
    end

    def last
      raw_last = apply_filters.last
      raw_last ? wrap_instance(raw_last) : nil
    end

    def find_by(conditions)
      raw_found = where(conditions).apply_filters.first
      raw_found ? wrap_instance(raw_found) : nil
    end
    
    def count
      results.length
    end
    
    def each(&block)
      all.each(&block)
    end
    
    def paginate(per_page:)
      raise ArgumentError, "per_page must be positive" if per_page <= 0
      
      total_items = raw_count
      return [Page.new([], 1, 1, total_items)] if total_items == 0

      total_pages = (total_items.to_f / per_page).ceil
      (1..total_pages).map do |page_num|
        offset_val = (page_num - 1) * per_page
        items_per_page = if @limit_count && (@limit_count < per_page)
                           remaining_items = [@limit_count - offset_val, 0].max
                           [remaining_items, per_page].min
                         else
                           per_page
                         end
        items = self.offset(offset_val).limit(items_per_page).to_a
        Page.new(items, page_num, total_pages, total_items)
      end
    end
    
    def raw_count
      apply_filters.length
    end
    
    def results
      @_results ||= apply_filters.map { |hash| wrap_instance(hash) }
    end
    
    def apply_filters
      result = @data.dup
      
      # Handle no conditions
      return apply_ordering_and_limits(result) if @conditions.empty?

      # Process conditions with proper AND/OR logic
      and_result = result.dup
      or_results = []

      @conditions.each do |condition|
        if condition.is_a?(Array)
          operator = condition[0]
          
          case operator
          when :or
            # OR with hash condition - evaluate against original dataset
            condition_hash = condition[1]
            matching = @data.select do |item|
              condition_hash.all? { |field, value| evaluate_condition(item, field.to_sym, value) }
            end
            or_results.concat(matching)
            
          when :or_block
            # OR with block condition - evaluate against original dataset
            sub_conditions = condition[1]
            temp_query = self.class.new(@model_name, @data, {}, @relations, conditions: sub_conditions)
            matching = temp_query.apply_filters
            or_results.concat(matching)
            
          when :and_block
            # AND with block condition - apply to current AND result
            sub_conditions = condition[1]
            temp_query = self.class.new(@model_name, and_result, {}, @relations, conditions: sub_conditions)
            and_result = temp_query.apply_filters
          end
        else
          # Regular AND condition
          and_result = and_result.select do |item|
            condition.all? { |field, value| evaluate_condition(item, field.to_sym, value) }
          end
        end
      end

      # Combine results: AND results + OR results (remove duplicates)
      final_result = and_result
      unless or_results.empty?
        final_result = (final_result + or_results).uniq
      end
      
      apply_ordering_and_limits(final_result)
    end

    private

    def apply_ordering_and_limits(data)
      result = data
      
      if @order_field
        # Separate nil values to always sort them to the end
        nil_items = result.select { |item| item[@order_field.to_sym].nil? }
        non_nil_items = result.reject { |item| item[@order_field.to_sym].nil? }
        
        # Sort non-nil items with proper type handling
        sorted_non_nil = non_nil_items.sort_by do |item|
          value = item[@order_field.to_sym]
          case value
          when Numeric then [0, value]
          when String then [1, value]
          when Date, Time then [2, value]
          else [3, value.to_s]
          end
        end
        
        result = @order_desc ? sorted_non_nil.reverse + nil_items : sorted_non_nil + nil_items
      end
      
      result = result[@offset_count..-1] || [] if @offset_count && @offset_count > 0
      result = result[0, @limit_count] || [] if @limit_count
      
      result
    end
    
    public :apply_filters
    
    private
    
    def evaluate_condition(item, field, value)
      field_value = item[field]
      
      case value
      when ::Hash
        if value.key?(:contains)
          field_value.to_s.include?(value[:contains].to_s)
        elsif value.key?(:starts_with)
          field_value.to_s.start_with?(value[:starts_with].to_s)
        elsif value.key?(:ends_with)
          field_value.to_s.end_with?(value[:ends_with].to_s)
        elsif value.key?(:greater_than)
          field_value && field_value > value[:greater_than]
        elsif value.key?(:less_than)
          field_value && field_value < value[:less_than]
        elsif value.key?(:greater_than_or_equal)
          field_value && field_value >= value[:greater_than_or_equal]
        elsif value.key?(:less_than_or_equal)
          field_value && field_value <= value[:less_than_or_equal]
        elsif value.key?(:from) && value.key?(:to)
          field_value && field_value >= value[:from] && field_value <= value[:to]
        elsif value.key?(:from)
          field_value && field_value >= value[:from]
        elsif value.key?(:to)
          field_value && field_value <= value[:to]
        elsif value.key?(:in)
          Array(value[:in]).include?(field_value)
        elsif value.key?(:not_in)
          !Array(value[:not_in]).include?(field_value)
        elsif value.key?(:not)
          field_value != value[:not]
        elsif value.key?(:exists)
          value[:exists] ? !field_value.nil? : field_value.nil?
        elsif value.key?(:empty)
          if value[:empty]
            field_value.nil? || field_value == '' || (field_value.respond_to?(:empty?) && field_value.empty?)
          else
            !field_value.nil? && field_value != '' && !(field_value.respond_to?(:empty?) && field_value.empty?)
          end
        else
          field_value == value
        end
      when Array
        field_value.is_a?(Array) ? field_value == value : value.include?(field_value)
      when Range
        value.include?(field_value)
      else
        field_value == value
      end
    end
    
    def wrap_instance(hash)
      InstanceWrapper.new(hash, @model_name)
    end
  end
end