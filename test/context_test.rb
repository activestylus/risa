require_relative 'test_helper'

module Risa
  class TestDefinitionContext < Minitest::Test
    def setup
      @context = DefinitionContext.new(:test_model, 'data')
    end

    def test_from_array_with_valid_array
      @context.from_array([{ id: 1, name: 'Test' }, { id: 2, name: 'Another' }])
      assert_equal 2, @context.loaded_data.size
      assert @context.loaded_data.all?(&:frozen?)
    end

    def test_from_array_with_non_array
      error = assert_raises(DataFileError) { @context.from_array('not an array') }
      assert_match /expects an Array of hashes, but got String/, error.message
    end

    def test_from_array_with_non_hash_item
      error = assert_raises(DataFileError) { @context.from_array(['not a hash']) }
      assert_match /array item 1 should be a Hash, but got String/, error.message
    end

    def test_scope_definition
      @context.scope({ test_scope: -> { self } })
      assert @context.scopes.key?(:test_scope)
    end

    def test_scope_non_callable
      assert_raises(Risa::ScopeError) { @context.scope({ test_scope: 'not callable' }) }
    end

    def test_load_with_files
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'file1.rb'), "{ id: 1, title: 'First' }")
        File.write(File.join(dir, 'file2.rb'), "{ id: 2, title: 'Second' }")
        
        context = DefinitionContext.new(:test, dir)
        context.load('*.rb')
        
        assert_equal 2, context.loaded_data.size
        assert_equal({ id: 1, title: 'First' }, context.loaded_data[0])
        assert_equal({ id: 2, title: 'Second' }, context.loaded_data[1])
        assert context.loaded_data.all?(&:frozen?)
      end
    end

    def test_load_no_files
      Dir.mktmpdir do |dir|
        context = DefinitionContext.new(:test, dir)
        error = assert_raises(Risa::DataFileError) { context.load('*.rb') }
        assert_match /No files found matching pattern/, error.message
      end
    end

    def test_load_non_hash
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'invalid.rb'), "'string'")
        context = DefinitionContext.new(:test, dir)
        error = assert_raises(DataFileError) { context.load('*.rb') }
        assert_match /should return a Hash, but returned String/, error.message
      end
    end

    def test_load_syntax_error
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'invalid.rb'), "{ id: 1,, }")
        context = DefinitionContext.new(:test, dir)
        error = assert_raises(DataFileError) { context.load('*.rb') }
        assert_match /has a syntax error/, error.message
      end
    end

    def test_load_generic_error
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'error.rb'), "raise 'boom'")
        context = DefinitionContext.new(:test, dir)
        error = assert_raises(DataFileError) { context.load('*.rb') }
        assert_match /couldn't be loaded:\nboom/, error.message
      end
    end
  end
end