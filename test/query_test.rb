require_relative 'test_helper'

module Risa
  class TestQuery < Minitest::Test
    def setup
      Risa.reload
      Risa.define :posts do
        from_array([
          { id: 1, title: 'Post 1', published_at: Date.new(2024, 1, 1), featured: true, tags: ['ruby', 'web'], views: 100 },
          { id: 2, title: 'Post 2', published_at: Date.new(2024, 2, 1), featured: false, tags: ['tools'], views: 200 },
          { id: 3, title: 'Post 3', published_at: Date.new(2023, 12, 1), featured: true, tags: ['ruby'], views: 150 },
          { id: 4, title: nil, published_at: nil, featured: nil, tags: [], views: nil }
        ])

        scope({
          featured: -> { where(featured: true) },
          recent: ->(n=2) { order(:published_at, desc: true).limit(n) },
          tagged: ->(tag) { where(tags: { contains: tag }) }
        })
      end
      
      Risa.present :posts do
        def title_upper
          self[:title]&.upcase
        end
        
        def view_category
          self[:views] && self[:views] > 150 ? 'popular' : 'standard'
        end
      end
      
      @query = Risa.query(:posts)
    end

    def teardown
      Risa.reload
    end

    def test_all
      assert_equal 4, @query.all.size
      assert @query.all.all? { |item| item.is_a?(InstanceWrapper) }
    end

    def test_first_and_last
      assert_equal 1, @query.first[:id]
      assert_equal 4, @query.last[:id]
    end

    def test_count
      assert_equal 4, @query.count
    end

    def test_find_by
      post = @query.find_by(id: 2)
      assert_equal 'Post 2', post[:title]
    end

    def test_where_equality
      query = @query.where(featured: true) 
      assert_equal [1, 3], query.map { |p| p[:id] }.sort
    end

    def test_where_hash_conditions
      results = @query.where(title: { contains: 'Post' })
      assert_equal 3, results.size

      results = @query.where(published_at: { greater_than: Date.new(2024, 1, 1) })
      assert_equal [2], results.map { |p| p[:id] }

      results = @query.where(published_at: { less_than: Date.new(2024, 1, 1) })
      assert_equal [3], results.map { |p| p[:id] }

      results = @query.where(published_at: { greater_than_or_equal: Date.new(2024, 1, 1) })
      assert_equal [1, 2], results.map { |p| p[:id] }.sort

      results = @query.where(published_at: { less_than_or_equal: Date.new(2024, 1, 1) })
      assert_equal [1, 3], results.map { |p| p[:id] }.sort

      results = @query.where(published_at: { from: Date.new(2024, 1, 1), to: Date.new(2024, 2, 1) })
      assert_equal [1, 2], results.map { |p| p[:id] }.sort

      results = @query.where(published_at: { from: Date.new(2024, 1, 1) })
      assert_equal [1, 2], results.map { |p| p[:id] }.sort

      results = @query.where(published_at: { to: Date.new(2024, 1, 1) })
      assert_equal [1, 3], results.map { |p| p[:id] }.sort

      results = @query.where(id: { in: [1, 3] })
      assert_equal [1, 3], results.map { |p| p[:id] }.sort

      results = @query.where(id: { not_in: [1, 3] })
      assert_equal [2, 4], results.map { |p| p[:id] }.sort

      results = @query.where(featured: { not: true })

      results = @query.where(tags: { empty: true })
      assert_equal [4], results.map { |p| p[:id] }

      results = @query.where(tags: { empty: false })
      assert_equal [1, 2, 3], results.map { |p| p[:id] }.sort

      results = @query.where(title: { exists: true })
      assert_equal 3, results.size

      results = @query.where(title: { exists: false })
      assert_equal [4], results.map { |p| p[:id] }

      results = @query.where(title: { starts_with: 'Post' })
      assert_equal 3, results.size

      results = @query.where(title: { ends_with: '1' })
      assert_equal [1], results.map { |p| p[:id] }
    end

    def test_where_array
      results = @query.where(id: [1, 3])
      assert_equal [1, 3], results.map { |p| p[:id] }.sort
    end

    def test_where_range
      results = @query.where(published_at: Date.new(2024, 1, 1)..Date.new(2024, 12, 31))
      assert_equal [1, 2], results.map { |p| p[:id] }.sort
    end

    def test_order_asc
      results = @query.order(:published_at)
      expected_order = [3, 1, 2, 4]
      assert_equal expected_order, results.map { |p| p[:id] }
    end

    def test_order_desc
      results = @query.order(:published_at, desc: true)
      expected_order = [2, 1, 3, 4]
      assert_equal expected_order, results.map { |p| p[:id] }
    end

    def test_limit_and_offset
      results = @query.order(:id).limit(2)
      assert_equal [1, 2], results.map { |p| p[:id] }

      results = @query.order(:id).offset(2).limit(1)
      assert_equal [3], results.map { |p| p[:id] }

      results = @query.order(:id).offset(1).limit(2)
      assert_equal [2, 3], results.map { |p| p[:id] }

      results = @query.order(:id).offset(10)
      assert_equal [], results.map { |p| p[:id] }
    end

    def test_chained_queries
      results = @query.where(featured: true).order(:published_at, desc: true).limit(1)
      assert_equal [1], results.map { |p| p[:id] }

      results = @query.where(views: { greater_than: 120 }).where(featured: true)
      assert_equal [3], results.map { |p| p[:id] }
    end

    def test_scopes
      featured = @query.featured.all
      assert_equal [1, 3], featured.map { |p| p[:id] }.sort

      recent = @query.recent.all
      assert_equal [2, 1], recent.map { |p| p[:id] }

      recent_3 = @query.recent(3)
      assert_equal [2, 1, 3], recent_3.map { |p| p[:id] }

      tagged = @query.tagged('ruby')
      assert_equal [1, 3], tagged.map { |p| p[:id] }.sort

      featured_ruby = @query.featured.tagged('ruby')
      assert_equal [1, 3], featured_ruby.map { |p| p[:id] }.sort
    end
    def test_scope_error_handling
      Risa.define :error_model do
        from_array([])
        scope({ bad: -> { raise 'boom' } })
      end
      query = Risa.query(:error_model)
      error = assert_raises(Risa::ScopeError) { query.bad }
      assert_match /Error in scope :bad for model :error_model/, error.message
    end

    def test_enumerable
      assert_equal 4, @query.size
      
      titles = @query.select { |p| p[:title] }.map { |p| p[:title] }
      assert_equal ['Post 1', 'Post 2', 'Post 3'], titles.sort

      featured_ids = @query.select { |p| p[:featured] }.map { |p| p[:id] }
      assert_equal [1, 3], featured_ids.sort

      assert @query.any? { |p| p[:featured] }
      assert @query.all? { |p| p[:id].is_a?(Integer) }
    end

    def test_symbol_normalization_in_conditions
      results = @query.where(title: { contains: 'Post' })
      assert_equal 3, results.size

      results = @query.where('id' => 1, :featured => true)
      assert_equal [1], results.map { |p| p[:id] }
    end

    def test_complex_conditions
      results = @query.where(featured: false)
      assert_equal [2], results.map { |p| p[:id] }

      results = @query.where(featured: nil)
      assert_equal [4], results.map { |p| p[:id] }

      results = @query.where(tags: ['ruby', 'web'])
      assert_equal [1], results.map { |p| p[:id] }
      
      results = @query.where(tags: ['tools'])
      assert_equal [2], results.map { |p| p[:id] }
    end
    
def test_or_where_hash
  results = @query.where(featured: true).or_where(views: { greater_than: 150 })
  # featured: true gives [1, 3], OR views > 150 gives [2], so combined should be [1, 2, 3]
  assert_equal [1, 2, 3], results.map { |p| p.id }.sort
end


def test_or_where_block
  results = @query.where { |q| q.where(id: 1).where(featured: false) } # This gives [] (no matches)
                 .or_where { |q| q.where(views: { greater_than_or_equal: 200 }) } # This gives [2]

  assert_equal [2], results.map { |p| p.id }
end

    def test_where_block_for_grouping
      results = @query.where(featured: true).where do |q|
        q.where(views: { less_than: 120 }).or_where(tags: { contains: 'ruby' })
      end
      assert_equal [1, 3], results.map { |p| p.id }.sort
    end

    def test_negation_with_where_not_hash
      results = @query.where(featured: { not: true })
      assert_equal [2, 4], results.map { |p| p.id }.sort
    end

def test_negation_with_or_where_not_hash
  results = @query.where(featured: true).or_where(title: { not: 'Post 2' })
  # featured: true gives [1, 3], OR title != 'Post 2' gives [1, 3, 4], so combined should be [1, 3, 4]
  assert_equal [1, 3, 4], results.map { |p| p.id }.sort
end
def test_complex_and_or_not
  results = @query.where { |q| q.where(featured: true).where(views: { less_than_or_equal: 150 }) } # [1, 3] AND views <= 150 gives [1, 3]
                 .or_where { |q| q.where(tags: { contains: 'web' }).where(views: { less_than: 150 }) } # tags: web AND views < 150 gives [1]
  
  # [1, 3] OR [1] = [1, 3]
  assert_equal [1, 3], results.map { |p| p.id }.sort
end
  end
end