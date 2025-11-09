# frozen_string_literal: true
require_relative 'relations'

module Risa
  class InstanceWrapper
    include Risa::Relations::Fetcher
    RESERVED_METHODS = [
      :class, :object_id, :hash, :to_s, :inspect, :nil?, :frozen?, 
      :clone, :dup, :taint, :untaint, :freeze, :equal?, :==, :===,
      :send, :public_send, :respond_to?, :method, :methods,
      :instance_variables, :instance_variable_get, :instance_variable_set,
      :instance_of?, :kind_of?, :is_a?, :to_h, :to_hash
    ].freeze

    def initialize(hash, model_name)
      @_hash = hash
      @_memoized = {}
      @_model_name = model_name
      @_relations = Risa.relations_for(@_model_name)
      @_presenter_module = Risa.presenter_for(@_model_name)

      @_hash.each_key do |key|
        method_name = key.to_sym
        next if RESERVED_METHODS.include?(method_name)
        
        define_singleton_method(method_name) do
          @_hash[key]
        end
      end

      @_relations.each_key do |relation_name|
        define_singleton_method(relation_name) do
          fetch_relation(relation_name)
        end
      end

      if @_presenter_module
        @_presenter_module.instance_methods(false).each do |method_name|
          original_method = @_presenter_module.instance_method(method_name)
          
          define_singleton_method(method_name) do |*args, &block|
            cache_key = [method_name, args]
            
            unless @_memoized.key?(cache_key)
              begin
                @_memoized[cache_key] = original_method.bind(self).call(*args, &block)
              rescue => e
                raise Risa::ItemMethodError,
                      "Error executing presenter method :#{method_name} on #{@_model_name} instance #{@_hash.inspect}: #{e.message}\n  #{e.backtrace&.first}"
              end
            end
            
            @_memoized[cache_key]
          end
        end
      end
    end

    def [](key)
      @_hash&.[](key.to_sym) || @_hash&.[](key)
    end

    def []=(key, value)
      raise "Risa::InstanceWrapper collections are immutable. Cannot assign #{key} = #{value}"
    end

    def respond_to?(method_name, include_private = false)
      symbol_name = method_name.to_sym
      return true if singleton_class.method_defined?(symbol_name)
      return true if @_presenter_module&.method_defined?(symbol_name)
      return true if @_hash&.key?(symbol_name) && !RESERVED_METHODS.include?(symbol_name)
      return true if @_relations&.key?(symbol_name)
      super
    end

    def inspect
      "#<Risa::Instance #{@_hash.inspect}>"
    end

    def to_h
      @_hash
    end

    def to_hash
      @_hash
    end
  end
end