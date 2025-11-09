require_relative 'test_helper'

class TestPagination < Minitest::Test
  def setup
    Risa.reload
    # Create a collection with 23 items for thorough pagination testing
    Risa.define :paginated_posts do
      from_array((1..23).map do |i|
        { 
          id: i, 
          title: "Post #{i}", 
          content: "Content for post #{i}",
          priority: i % 3,  # 0, 1, 2, 0, 1, 2, ...
          published: i <= 20 # First 20 are published
        }
      end)

      scope({
        published: -> { where(published: true) },
        by_priority: ->(p) { where(priority: p) }
      })
    end
    
    # ADD THIS PRESENTER BLOCK INSTEAD OF THE item BLOCK
    Risa.present :paginated_posts do
      def slug
        "post-#{self[:id]}"
      end
      
      def excerpt
        "#{self[:content][0..20]}..."
      end
    end
    
    @query = Risa.query(:paginated_posts)
  end

  def teardown
    Risa.reload
  end

  def test_basic_pagination
    pages = @query.paginate(per_page: 5)
    
    assert_equal 5, pages.length
    
    first_page = pages.first
    assert_instance_of Risa::Page, first_page
    assert_equal 5, first_page.items.size
    assert_equal 1, first_page.current_page
    assert_equal 5, first_page.total_pages
    assert_equal 23, first_page.total_items
    assert_nil first_page.prev_page
    assert_equal 2, first_page.next_page
    assert first_page.is_first_page
    refute first_page.is_last_page
    
    middle_page = pages[2]
    assert_equal 5, middle_page.items.size
    assert_equal 3, middle_page.current_page
    assert_equal 2, middle_page.prev_page
    assert_equal 4, middle_page.next_page
    refute middle_page.is_first_page
    refute middle_page.is_last_page
    
    last_page = pages.last
    assert_equal 3, last_page.items.size
    assert_equal 5, last_page.current_page
    assert_equal 4, last_page.prev_page
    assert_nil last_page.next_page
    refute last_page.is_first_page
    assert last_page.is_last_page
  end

  def test_pagination_with_chaining
    published_pages = @query.published.paginate(per_page: 8)
    
    assert_equal 3, published_pages.length
    assert_equal 20, published_pages.first.total_items
    
    ordered_query = @query.order(:id, desc: true)
    
    ordered_pages = ordered_query.paginate(per_page: 6)
    first_page_items = ordered_pages.first.items
    expected_ids = [23, 22, 21, 20, 19, 18]
    assert_equal expected_ids, first_page_items.map { |item| item[:id] }
    
    priority_pages = @query.by_priority(1).paginate(per_page: 3)
    assert_equal 3, priority_pages.length
    assert_equal 8, priority_pages.first.total_items
  end

  def test_single_page_collection
    limited_query = @query.limit(5)
    small_pages = limited_query.paginate(per_page: 10)
    
    assert_equal 1, small_pages.length
    page = small_pages.first
    assert_equal 5, page.items.size
    assert_equal 1, page.current_page
    assert_equal 1, page.total_pages
    assert_equal 5, page.total_items
    assert_nil page.prev_page
    assert_nil page.next_page
    assert page.is_first_page
    assert page.is_last_page
  end

  def test_empty_collection_pagination
    empty_pages = @query.where(id: 999).paginate(per_page: 5)
    
    assert_equal 1, empty_pages.length
    page = empty_pages.first
    assert_equal [], page.items
    assert_equal 1, page.current_page
    assert_equal 1, page.total_pages
    assert_equal 0, page.total_items
  end

  def test_pagination_error_handling
    error = assert_raises(ArgumentError) { @query.paginate(per_page: 0) }
    assert_match /per_page must be positive/, error.message
    
    error = assert_raises(ArgumentError) { @query.paginate(per_page: -5) }
    assert_match /per_page must be positive/, error.message
  end

  def test_page_object_methods
    pages = @query.paginate(per_page: 7)
    page = pages[1]
    
    first_item = page.items.first
    assert_equal "post-#{first_item[:id]}", first_item.slug
    assert_match /Content for post \d+\.\.\./, first_item.excerpt
    
    assert_equal page.items, page.posts
    
    page_hash = page.to_h
    expected_keys = [:items, :current_page, :total_pages, :total_items, 
                    :prev_page, :next_page, :is_first_page, :is_last_page]
    assert_equal expected_keys.sort, page_hash.keys.sort
    assert_equal page.current_page, page_hash[:current_page]
    assert_equal page.total_items, page_hash[:total_items]
    assert_equal page.is_first_page, page_hash[:is_first_page]
  end

  def test_pagination_maintains_order
    ordered_pages = @query.order(:id).paginate(per_page: 6)
    
    all_items = []
    ordered_pages.each { |page| all_items.concat(page.items) }
    
    ids = all_items.map { |item| item[:id] }
    assert_equal (1..23).to_a, ids
  end

  def test_pagination_edge_cases
    exact_pages = @query.limit(10).paginate(per_page: 10)
    assert_equal 1, exact_pages.length
    assert_equal 10, exact_pages.first.items.size
    
    limited_query = @query.limit(3)
    large_pages = limited_query.paginate(per_page: 10)
    assert_equal 1, large_pages.length
    assert_equal 3, large_pages.first.items.size
    assert_equal 3, large_pages.first.total_items
    
    limited_query_5 = @query.limit(5)
    single_pages = limited_query_5.paginate(per_page: 1)
    assert_equal 5, single_pages.length
    assert_equal 5, single_pages.first.total_items
    single_pages.each_with_index do |page, index|
      assert_equal 1, page.items.size
      assert_equal index + 1, page.current_page
      assert_equal 5, page.total_pages
    end
  end
end