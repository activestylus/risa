# frozen_string_literal: true

module Risa
  module Inflector
    def self.pluralize(word)
      str = word.to_s
      str.end_with?('s') ? str : "#{str}s"
    end

    def self.singularize(word)
      str = word.to_s
      str.end_with?('s') ? str.chomp('s') : str
    end
  end

  module Relations
    module DSL
      def relations
        @relations ||= {}
      end

      def belongs_to(name, class_name: nil, foreign_key: nil, primary_key: :id)
        relations[name.to_sym] = {
          type: :belongs_to,
          class_name: class_name || Risa::Inflector.pluralize(name).to_sym,
          foreign_key: foreign_key || "#{name}_id".to_sym,
          primary_key: primary_key
        }
      end

      def has_many(name, class_name: nil, foreign_key: nil, through: nil, source: nil, owner_key: :id)
        options = { type: :has_many, owner_key: owner_key }
        if through
          options[:through] = through.to_sym
          options[:source] = source || Risa::Inflector.singularize(name).to_sym
        else
          options[:class_name] = class_name || name.to_sym
          options[:foreign_key] = foreign_key || "#{Risa::Inflector.singularize(@model_name)}_id".to_sym
        end
        relations[name.to_sym] = options
      end

      def has_one(name, class_name: nil, foreign_key: nil, owner_key: :id)
        relations[name.to_sym] = {
          type: :has_one,
          class_name: class_name || Risa::Inflector.pluralize(name).to_sym,
          foreign_key: foreign_key || "#{Risa::Inflector.singularize(@model_name)}_id".to_sym,
          owner_key: owner_key
        }
      end
    end # End DSL

    module Fetcher
      private

      def fetch_relation(name)
        @_memoized[name] ||= begin
          relation = @_relations[name]
          raise "Undefined relation '#{name}' called on model '#{@_model_name}'" unless relation

          case relation[:type]
          when :belongs_to
            fetch_belongs_to(relation)
          when :has_one
            fetch_has_one(relation)
          when :has_many
            relation[:through] ? fetch_has_many_through(relation) : fetch_has_many_direct(relation)
          else
            raise "Unknown relation type: #{relation[:type]}"
          end
        end
      end

      def fetch_belongs_to(relation)
        foreign_key_value = @_hash[relation[:foreign_key]]
        primary_key = relation[:primary_key]
        foreign_key_value ? Risa.query(relation[:class_name]).find_by(primary_key => foreign_key_value) : nil
      end

      def fetch_has_one(relation)
        owner_key_value = @_hash[relation[:owner_key]]
        Risa.query(relation[:class_name]).find_by(relation[:foreign_key] => owner_key_value)
      end

      def fetch_has_many_direct(relation)
        owner_key_value = @_hash[relation[:owner_key]]
        Risa.query(relation[:class_name]).where(relation[:foreign_key] => owner_key_value)
      end

      def fetch_has_many_through(relation)
        through_association_name = relation[:through]
        source_association_name = relation[:source]

        through_relation = @_relations[through_association_name]
        unless through_relation && through_relation[:type] == :has_many && !through_relation[:through]
          raise "Invalid 'through' association: #{through_association_name} on model '#{@_model_name}'. Must be a direct has_many."
        end
        intermediate_model_name = through_relation[:class_name]
        intermediate_foreign_key = through_relation[:foreign_key]
        intermediate_owner_key = through_relation[:owner_key]

        intermediate_relations = Risa.relations_for(intermediate_model_name)
        target_relation_on_intermediate = intermediate_relations[source_association_name]

        unless target_relation_on_intermediate && target_relation_on_intermediate[:type] == :belongs_to
           inferred_belongs_to = intermediate_relations.values.find do |rel|
             rel[:type] == :belongs_to && Risa::Inflector.pluralize(rel[:class_name]).to_sym == source_association_name
           end
           target_relation_on_intermediate = inferred_belongs_to
        end

        unless target_relation_on_intermediate && target_relation_on_intermediate[:type] == :belongs_to
           raise("Cannot find target 'belongs_to' association " \
                 "(expected name like ':#{source_association_name}' or similar, found: #{intermediate_relations.keys.inspect}) " \
                 "on intermediate model '#{intermediate_model_name}' for through relation " \
                 "'#{through_association_name}' on model '#{@_model_name}'. Did you define the belongs_to on #{intermediate_model_name}?")
        end

        final_model_name = target_relation_on_intermediate[:class_name]
        final_foreign_key_on_intermediate = target_relation_on_intermediate[:foreign_key]
        final_primary_key = target_relation_on_intermediate[:primary_key]

        intermediate_records = Risa.query(intermediate_model_name)
                                  .where(intermediate_foreign_key => @_hash[intermediate_owner_key])
                                  .to_a

        target_ids = intermediate_records.map { |record| record[final_foreign_key_on_intermediate] }.compact.uniq

        target_ids.empty? ? Risa.query(final_model_name).where(id: -1) : Risa.query(final_model_name).where(final_primary_key => { in: target_ids })
      end
    end # End Fetcher
  end # End Relations
end # End Risa