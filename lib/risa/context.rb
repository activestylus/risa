# frozen_string_literal: true
require_relative 'relations'

module Risa
  class DefinitionContext
    include Risa::Relations::DSL

    attr_reader :loaded_data, :scopes

    def initialize(model_name, data_path)
      @model_name = model_name
      @data_path = data_path
      @loaded_data = []
      @scopes = {}
      @relations = {}
    end

    def load(pattern)
      file_pattern = File.join(@data_path, pattern)
      files = Dir[file_pattern].sort
      
      raise DataFileError, "No files found matching pattern: #{file_pattern}" if files.empty?
      
      @loaded_data = files.map do |file|
        begin
          hash_data = eval(File.read(file), TOPLEVEL_BINDING, file)
          
          unless hash_data.is_a?(::Hash)
            raise DataFileError, "#{file} should return a Hash, but returned #{hash_data.class}"
          end
          
          hash_data.freeze
        rescue DataFileError => e
          raise e
        rescue SyntaxError => e
          raise DataFileError, "#{file} has a syntax error:\n#{e.message}"
        rescue => e
          raise DataFileError, "#{file} couldn't be loaded:\n#{e.message}"
        end
      end
    end

    def from_array(array)
      unless array.is_a?(Array)
        raise DataFileError, "from_array() expects an Array of hashes, but got #{array.class}"
      end
      
      @loaded_data = array.map.with_index do |item, index|
        unless item.is_a?(::Hash)
          raise DataFileError, "from_array() array item #{index + 1} should be a Hash, but got #{item.class}"
        end
        item.freeze
      end
    end

    def scope(methods_hash)
      methods_hash.each do |name, lambda_proc|
        unless lambda_proc.respond_to?(:call)
          raise ScopeError, "Scope #{name} must be callable (lambda or proc)"
        end
        @scopes[name.to_sym] = lambda_proc
      end
    end
  end
end