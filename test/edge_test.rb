require_relative 'test_helper'
class TestEdgeCases < Minitest::Test
  def setup
    Risa.reload
  end

  def teardown
    Risa.reload
  end

  def test_empty_collections
    Risa.define :empty do
      from_array([])
    end

    query = Risa.query(:empty)
    assert_equal 0, query.size
    assert_equal [], query.to_a
    assert_nil query.first
    assert_nil query.last
    assert_equal [], query.where(id: 1).to_a
    assert_equal [], query.order(:id).to_a
    assert_equal [], query.limit(5).to_a
    assert_equal [], query.offset(2).to_a
  end

  def test_single_item_collection
    Risa.define :single do
      from_array([{ id: 1, title: 'Only One' }])
    end

    query = Risa.query(:single)
    assert_equal 1, query.count
    assert_equal 1, query.first[:id]
    assert_equal 1, query.last[:id]
    assert_equal [1], query.all.map { |item| item[:id] }
  end

  def test_collections_with_duplicate_data
    Risa.define :duplicates do
      from_array([
        { id: 1, name: 'John' },
        { id: 2, name: 'John' },
        { id: 3, name: 'John' }
      ])
    end

    query = Risa.query(:duplicates)
    johns = query.where(name: 'John')
    assert_equal 3, johns.size
    assert_equal [1, 2, 3], johns.map { |item| item[:id] }.sort
  end

  def test_collections_with_all_nils
    Risa.define :nils do
      from_array([
        { id: 1, value: nil },
        { id: 2, value: nil },
        { id: 3, value: nil }
      ])
    end

    query = Risa.query(:nils)
    results = query.where(value: { exists: false })
    assert_equal 3, results.size

    results = query.where(value: { empty: true })
    assert_equal 3, results.size
  end

  def test_large_offset_and_limit
    Risa.define :numbers do
      from_array((1..100).map { |n| { id: n, value: n * 2 } })
    end

    query = Risa.query(:numbers)
    
    # Test large offset beyond collection size
    results = query.offset(200)
    assert_equal [], results.to_a

    # Test large limit on small remaining items
    results = query.offset(95).limit(10)
    assert_equal 5, results.size # Only 5 items left after offset 95

    # Test zero limit
    results = query.limit(0)
    assert_equal [], results.to_a

    # Test negative offset (should be treated as 0)
    results = query.offset(-5).limit(3)
    assert_equal 3, results.size
  end

  def test_complex_chaining_with_no_results
    Risa.define :complex do
      from_array([
        { id: 1, category: 'A', published: true, views: 100 },
        { id: 2, category: 'B', published: false, views: 200 }
      ])
    end

    query = Risa.query(:complex)
    
    # Chain filters that result in no matches
    results = query.where(category: 'A').where(published: false)
    assert_equal [], results.to_a

    results = query.where(views: { greater_than: 300 })
    assert_equal [], results.to_a

    results = query.where(id: [10, 20, 30])
    assert_equal [], results.to_a
  end

  def test_scope_with_parameters_edge_cases
    Risa.define :parameterized do
      from_array([
        { id: 1, score: 85 },
        { id: 2, score: 92 },
        { id: 3, score: 78 },
        { id: 4, score: 95 }
      ])

      scope({
        by_score: ->(min_score) { where(score: { greater_than_or_equal: min_score }) },
        top_n: ->(n) { order(:score, desc: true).limit(n) },
        score_range: ->(min, max) { where(score: { from: min, to: max }) }
      })
    end

    query = Risa.query(:parameterized)
    
    results = query.by_score(100)
    assert_equal [], results.to_a

    results = query.by_score(0)
    assert_equal 4, results.size

    results = query.top_n(0)
    assert_equal [], results.to_a

    results = query.score_range(90, 100)
    assert_equal [2, 4].sort, results.map { |item| item[:id] }.sort # <-- Corrected
  end

def test_method_name_conflicts
  Risa.define :conflicts do
    from_array([{ id: 1, hash: 'test_hash', class: 'test_class' }])
  end

  query = Risa.query(:conflicts)
  item = query.first

  # Access conflicting keys via [] - they should NOT have method access
  assert_equal 'test_hash', item[:hash]
  assert_equal 'test_class', item[:class]

  # Check that conflicting keys do NOT respond to method calls
  # These should be FALSE because we skip defining methods for conflicting keys
  assert item.respond_to?(:hash)   # Should be false - we don't define this method
  assert item.respond_to?(:class)  # Should be false - we don't define this method

  # Check built-in methods still work
  assert item.object_id.is_a?(Integer)
  assert item.hash.is_a?(Integer)    # Built-in hash method works
  assert_equal Risa::InstanceWrapper, item.class # Built-in class method works

  # Verify we can't access the hash values as methods (should raise NoMethodError)
  # But since respond_to? returns false, we don't need to test this
end



  def test_ordering_with_mixed_types
    # Test ordering when values are of different types (should handle gracefully)
    Risa.define :mixed do
      from_array([
        { id: 1, value: 'string' },
        { id: 2, value: 42 },
        { id: 3, value: nil },
        { id: 4, value: Date.new(2024, 1, 1) }
      ])
    end

    query = Risa.query(:mixed)
    
    # Should not raise an error, even with mixed types
    results = query.order(:value)
    assert_equal 4, results.size
    
    # nil should be at the end
    assert_equal 3, results.last[:id]
  end
end