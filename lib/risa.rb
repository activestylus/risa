# frozen_string_literal: true

require 'forwardable'
require 'json'
require 'date'
require_relative 'risa/context'
require_relative 'risa/instance'
require_relative 'risa/page'
require_relative 'risa/query'
require_relative 'risa/relations'

module Risa
  class DataFileError < StandardError; end
  class ScopeError < StandardError; end
  class ItemMethodError < StandardError; end
  
  class << self
    def configure(data_path: 'data')
      @data_path = data_path
    end
    
    def load_from(data_dir)
      absolute_dir = File.expand_path(data_dir, Dir.pwd)
      
      Dir[File.join(absolute_dir, '**', '*.rb')].sort.each do |file|
        load file  # Use load, not require - allows reloading
      end
    end
    
    def reload_from(data_dir)
      Risa.reload
      load_from(data_dir)
    end

    def define(model_name, &block)
      context = DefinitionContext.new(model_name, @data_path || 'data')
      context.instance_eval(&block)
      
      @collections ||= {}
      @collections[model_name.to_sym] = {
        data: context.loaded_data,
        scopes: context.scopes,
        relations: context.relations  # Make sure this line exists
      }
    end
        
    def present(model_name, &block)
      presenter_module = Module.new
      presenter_module.module_eval(&block)
      (@presenter_modules ||= {})[model_name.to_sym] = presenter_module
    end
    
    def presenter_for(model_name)
      (@presenter_modules || {})[model_name.to_sym]
    end
    
    def query(model_name)
      model_name = model_name.to_sym
      collection = @collections[model_name]
      
      unless collection
        raise "Collection #{model_name} not defined. Use Risa.define :#{model_name} to define it."
      end
      
      Query.new(
        model_name, 
        collection[:data], 
        collection[:scopes],
        collection[:relations]
      )
    end
    
    def reload
      @collections = {}
      @presenter_modules = {}
    end
    
    def defined_models
      (@collections || {}).keys
    end
    
    def relations_for(model_name)
      (@collections || {}).dig(model_name.to_sym, :relations) || {}
    end
  end
end

def rs(model_name)
  Risa.query(model_name)
end