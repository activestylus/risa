require_relative 'test_helper'

module Risa
  class TestInstanceWrapper < Minitest::Test
    def setup
      @hash = { id: 1, title: 'Test', content: 'Long content here for testing purpose', views: 100, published_at: Date.new(2024, 1, 1) }.freeze
      
      Risa.present :test_model do
        def excerpt(words = 2)
          self[:content].split.take(words).join(' ') + '...'
        end
        
        def title_upper
          self[:title].upcase
        end
        
        def formatted_date
          self[:published_at]&.strftime("%B %d, %Y")
        end
        
        def view_category
          self[:views] && self[:views] > 150 ? 'popular' : 'standard'
        end
        
        def word_count
          self[:content].split.size
        end
        
        def summary(max_words = 10)
          words = self[:content].split.take(max_words)
          "#{words.join(' ')}#{words.size >= max_words ? '...' : ''}"
        end
      end
      
      @wrapper = Risa::InstanceWrapper.new(@hash, :test_model)
    end
    
    def teardown
      Risa.reload
    end

    def test_dot_notation_access_for_hash_keys
      assert_equal @hash[:id], @wrapper.id
      assert_equal @hash[:title], @wrapper.title
      assert_equal @hash[:content], @wrapper.content
      assert_equal @hash[:views], @wrapper.views
      assert_equal @hash[:published_at], @wrapper.published_at
      assert @wrapper.respond_to?(:id)
      assert @wrapper.respond_to?(:title)
      refute @wrapper.respond_to?(:some_random_method_that_does_not_exist)
    end

    def test_dot_notation_access_for_presenter_methods
      assert_equal 'Long content...', @wrapper.excerpt
      assert_equal 'Long...', @wrapper.excerpt(1)
      assert_equal 'TEST', @wrapper.title_upper
      assert @wrapper.respond_to?(:excerpt)
      assert @wrapper.respond_to?(:title_upper)
    end

    def test_hash_access
      assert_equal 1, @wrapper[:id]
      assert_equal 'Test', @wrapper[:title]
      assert_equal 'Test', @wrapper['title']
      assert_equal 100, @wrapper[:views]
      assert_nil @wrapper[:non_existent]
    end

    def test_symbol_string_key_normalization
      assert_equal 'Test', @wrapper[:title]
      assert_equal 'Test', @wrapper['title']
      assert_equal 1, @wrapper[:id]
      assert_equal 1, @wrapper['id']
    end

    def test_immutability
      error = assert_raises(RuntimeError) { @wrapper[:id] = 2 }
      assert_match /immutable/, error.message
      error = assert_raises(RuntimeError) { @wrapper['title'] = 'New Title' }
      assert_match /immutable/, error.message
    end

    def test_presenter_methods
      assert_equal 'Long content...', @wrapper.excerpt
      assert_equal 'Long...', @wrapper.excerpt(1)
      assert_equal 'Long content here...', @wrapper.excerpt(3)
      assert_equal 'TEST', @wrapper.title_upper
      assert_equal 'January 01, 2024', @wrapper.formatted_date
      assert_equal 'standard', @wrapper.view_category
      assert_equal 6, @wrapper.word_count
    end

    def test_presenter_methods_with_parameters
      assert_equal 'Long content...', @wrapper.excerpt(2)
      assert_equal 'Long content here for...', @wrapper.excerpt(4)
      assert_equal 'Long content here for testing...', @wrapper.summary(5)
      assert_equal 'Long content here for testing purpose', @wrapper.summary(10)
    end

    def test_memoization
      result1 = @wrapper.excerpt
      result2 = @wrapper.excerpt
      assert_equal result1, result2
      assert_equal 'Long content...', result1
      result3 = @wrapper.excerpt(1)
      assert_equal 'Long...', result3
      refute_equal result1, result3
      result4 = @wrapper.excerpt(1)
      assert_equal result3, result4
      date1 = @wrapper.formatted_date
      date2 = @wrapper.formatted_date
      assert_equal date1, date2
      assert_equal 'January 01, 2024', date1
    end

    def test_presenter_method_with_nil_handling
      nil_hash = { id: 1, title: nil, content: nil, published_at: nil }.freeze
      
      Risa.present :nil_test_model do
        def safe_title
          self[:title] || 'Untitled'
        end
        
        def safe_date
          self[:published_at]&.strftime("%Y-%m-%d") || 'No date'
        end
        
        def content_length
          (self[:content] || '').length
        end
      end
      
      wrapper = InstanceWrapper.new(nil_hash, :nil_test_model)
      assert_equal 'Untitled', wrapper.safe_title
      assert_equal 'No date', wrapper.safe_date
      assert_equal 0, wrapper.content_length
    end

    def test_presenter_method_error
      Risa.present :error_test_model do
        def bad
          raise 'boom'
        end
        
        def another_bad
          undefined_method_call
        end
      end
      
      wrapper = Risa::InstanceWrapper.new(@hash, :error_test_model)
      error = assert_raises(Risa::ItemMethodError) { wrapper.bad }
      assert_match /Error executing presenter method :bad.*boom/, error.message
      error = assert_raises(Risa::ItemMethodError) { wrapper.another_bad }
      assert_match /Error executing presenter method :another_bad/, error.message
    end

    def test_hash_methods
      expected_keys = [:id, :title, :content, :views, :published_at]
      assert_equal expected_keys.sort, @wrapper.to_h.keys.sort
      assert_equal @hash.values.size, @wrapper.to_h.values.size
      assert_equal @hash, @wrapper.to_h
      assert_equal @hash, @wrapper.to_hash
    end

    def test_method_missing_for_hash
      assert_equal 1, @wrapper[:id]
      assert_equal 'Test', @wrapper[:title]
      assert_equal 5, @wrapper.to_h.size
      assert @wrapper.respond_to?(:id)
      assert_equal 1, @wrapper.id
      assert @wrapper.to_h.has_key?(:id)
      assert @wrapper.to_h.has_key?(:title)
      refute @wrapper.to_h.has_key?(:non_existent)
      assert @wrapper.to_h.include?(:id)
      assert_equal @hash.length, @wrapper.to_h.length
      assert_equal false, @wrapper.to_h.empty?
      assert @wrapper.respond_to?(:to_h)
      assert @wrapper.respond_to?(:[])
    end

    def test_respond_to_for_dynamic_methods
      assert @wrapper.respond_to?(:id)
      assert @wrapper.respond_to?(:title)
      assert @wrapper.respond_to?(:excerpt)
      assert @wrapper.respond_to?(:title_upper)
      assert @wrapper.respond_to?(:formatted_date)
      refute @wrapper.to_h.has_key?(:non_existent)
      assert @wrapper.respond_to?(:class)
      assert @wrapper.respond_to?(:object_id)
      assert @wrapper.respond_to?(:to_h)
      refute @wrapper.respond_to?(:keys)
      refute @wrapper.respond_to?(:values)
      refute @wrapper.respond_to?(:size)
    end

    def test_inspect
      assert_match /#<Risa::Instance {.*}>/, @wrapper.inspect
      assert_match /id.*1/, @wrapper.inspect
      assert_match /title.*"Test"/, @wrapper.inspect
    end

    def test_complex_presenter_methods
      complex_hash = { 
        tags: ['ruby', 'web', 'programming'], 
        metadata: { author: 'John', category: 'tech' },
        scores: [85, 90, 78, 92]
      }.freeze
      
      Risa.present :complex_test_model do
        def tag_list
          self[:tags].join(', ')
        end
        
        def author_name
          self[:metadata][:author]
        end
        
        def average_score
          self[:scores].sum.to_f / self[:scores].length
        end
        
        def top_score
          self[:scores].max
        end
        
        def tag_count
          self[:tags].length
        end
      end
      
      wrapper = InstanceWrapper.new(complex_hash, :complex_test_model)
      assert_equal 'ruby, web, programming', wrapper.tag_list
      assert_equal 'John', wrapper.author_name
      assert_equal 86.25, wrapper.average_score
      assert_equal 92, wrapper.top_score
      assert_equal 3, wrapper.tag_count
    end
  end
end