require_relative 'test_helper'

class TestRelations < Minitest::Test
  def setup
    Risa.reload

    Risa.define :authors do
      from_array([
        { id: 1, name: 'Alice' },
        { id: 2, name: 'Bob' },
        { id: 3, name: 'Charlie' }
      ])
      has_many :posts
      has_one :profile
    end

    Risa.define :posts do
      from_array([
        { id: 101, title: 'Intro to HashQuery', author_id: 1, published: true, content: '...' },
        { id: 102, title: 'Advanced Ruby', author_id: 1, published: false, content: '...' },
        { id: 103, title: 'Web Development', author_id: 2, published: true, content: '...' },
        { id: 104, title: 'Orphaned Post', author_id: nil, published: true, content: '...' }
      ])
      belongs_to :author
      has_many :post_tags
      has_many :tags, through: :post_tags
    end

    Risa.define :profiles do
      from_array([
        { id: 201, bio: 'Ruby Developer', author_id: 1 },
        { id: 202, bio: 'Web Enthusiast', author_id: 2 }
      ])
      belongs_to :author
    end

    Risa.define :tags do
      from_array([
        { id: 301, name: 'ruby' },
        { id: 302, name: 'web' },
        { id: 303, name: 'performance' }
      ])
      has_many :post_tags
      has_many :posts, through: :post_tags
    end

    Risa.define :post_tags do
      from_array([
        { id: 401, post_id: 101, tag_id: 301 },
        { id: 402, post_id: 101, tag_id: 302 },
        { id: 403, post_id: 102, tag_id: 301 },
        { id: 404, post_id: 103, tag_id: 302 }
      ])
      belongs_to :post
      belongs_to :tag
    end

    Risa.define :users do
      from_array([ { user_pk: 501, username: 'admin' } ])
      has_many :articles, class_name: :articles, foreign_key: :creator_id, owner_key: :user_pk
    end

    Risa.define :articles do
      from_array([
        { id: 601, title: 'User Article', creator_id: 501 }
      ])
      belongs_to :creator, class_name: :users, foreign_key: :creator_id, primary_key: :user_pk
    end
  end

  def teardown
    Risa.reload
  end

  def test_belongs_to_finds_parent
    post = all(:posts).find_by(id: 101)
    author = post.author

    assert_instance_of Risa::InstanceWrapper, author
    assert_equal 1, author.id
    assert_equal 'Alice', author.name
    assert post.respond_to?(:author)
  end

  def test_belongs_to_returns_nil_if_fk_nil
    post = all(:posts).find_by(id: 104)
    assert_nil post.author
  end

  def test_belongs_to_returns_nil_if_parent_missing
    post = Risa::InstanceWrapper.new({ id: 105, title: 'Missing Author Post', author_id: 999 }, :posts)
    author = post.author
    assert_nil author
  end

  def test_belongs_to_with_custom_keys
    article = all(:articles).find_by(id: 601)
    creator = article.creator

    assert_instance_of Risa::InstanceWrapper, creator
    assert_equal 'admin', creator.username
    assert article.respond_to?(:creator)
  end

  def test_has_many_returns_query
    alice = all(:authors).find_by(id: 1)
    posts_query = alice.posts

    assert_instance_of Risa::Query, posts_query
    assert alice.respond_to?(:posts)
  end

  def test_has_many_retrieves_children
    alice = all(:authors).find_by(id: 1)
    posts = alice.posts.order(:id)

    assert_equal 2, posts.size
    assert_equal [101, 102], posts.map { |p| p.id }
    assert_equal ['Intro to HashQuery', 'Advanced Ruby'], posts.map { |p| p.title }
  end

  def test_has_many_allows_chaining
    alice = all(:authors).find_by(id: 1)
    published_posts = alice.posts.where(published: true)

    assert_equal 1, published_posts.size
    assert_equal 101, published_posts.first.id
  end

  def test_has_many_returns_empty_query_if_no_children
    charlie = all(:authors).find_by(id: 3)
    posts_query = charlie.posts

    assert_instance_of Risa::Query, posts_query
    assert_equal 0, posts_query.size
    assert_equal [], posts_query.to_a
  end

  def test_has_many_with_custom_keys
    user = all(:users).first
    articles_query = user.articles

    assert_instance_of Risa::Query, articles_query
    assert_equal 1, articles_query.size
    assert_equal 601, articles_query.first.id
    assert user.respond_to?(:articles)
  end

  def test_has_one_finds_child
    alice = all(:authors).find_by(id: 1)
    profile = alice.profile

    assert_instance_of Risa::InstanceWrapper, profile
    assert_equal 201, profile.id
    assert_equal 'Ruby Developer', profile.bio
    assert alice.respond_to?(:profile)
  end

  def test_has_one_returns_nil_if_no_child
    charlie = all(:authors).find_by(id: 3)
    profile = charlie.profile

    assert_nil profile
  end

  def test_has_many_through_returns_query
    post = all(:posts).find_by(id: 101)
    tags_query = post.tags

    assert_instance_of Risa::Query, tags_query
    assert post.respond_to?(:tags)
  end

  def test_has_many_through_retrieves_targets
    post = all(:posts).find_by(id: 101)
    tags = post.tags.order(:id)

    assert_equal 2, tags.size
    assert_equal [301, 302], tags.map { |t| t.id }
    assert_equal ['ruby', 'web'], tags.map { |t| t.name }
  end

  def test_has_many_through_allows_chaining
    post = all(:posts).find_by(id: 101)
    ruby_tag = post.tags.where(name: 'ruby')

    assert_equal 1, ruby_tag.size
    assert_equal 301, ruby_tag.first.id
  end

  def test_has_many_through_returns_empty_query_if_no_targets
    post = all(:posts).find_by(id: 104)
    tags_query = post.tags

    assert_instance_of Risa::Query, tags_query
    assert_equal 0, tags_query.size
    assert_equal [], tags_query.to_a
  end

  def test_has_many_through_inverse
    tag = all(:tags).find_by(id: 301)
    posts_query = tag.posts

    assert_instance_of Risa::Query, posts_query
    assert tag.respond_to?(:posts)

    posts = posts_query.order(:id)
    assert_equal 2, posts.size
    assert_equal [101, 102], posts.map { |p| p.id }
  end
end