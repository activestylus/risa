# Risa (Ruby Is So Awesome)

## Advanced Querying & Presentation Layer for Ruby Hashes 

You know that feeling when you're prototyping and you just need to store some structured data without the ceremony of setting up a database, migrations, and ORMs? 

Or when you're building a static site and you're tired of wrestling with YAML parsing errors and JSON schema headaches? 

Meet Risa. It's the Ruby library you didn't know you were missing.

## The "Aha!" Moment

```ruby
# Instead of this YAML nightmare:
# data/posts.yml
# ---
# - id: 1
#   title: "My Post" # YAML gotcha: this needs quotes
#   published_at: 2024-01-01 # Is this a string? Date? Who knows!

# You write pure Ruby (like you wanted all along):
Risa.define :posts do
  from_array([
    { id: 1, title: 'Hello World', published: true, created_at: Date.new(2024, 1, 1) },
    { id: 2, title: 'Ruby Magic', published: false, created_at: Date.new(2024, 1, 15) }
  ])
end

# Query it like you always wished you could:
rs(:posts).where(published: true).order(:created_at, desc: true).first[:title]
# => "Hello World"
```

No schema. No migrations. No database setup. Just Ruby being Ruby.

---

## Installation

```ruby
# Gemfile
gem 'risa'

# Or if you're feeling spontaneous:
gem install joys
```

## Quick Start: From Zero to Querying in 30 Seconds

```ruby
require 'risa'

# Define your data (arrays, files, whatever)
Risa.define :posts do
  from_array([
    { id: 1, title: 'Why I Love Ruby', tags: ['ruby', 'opinion'], views: 1337 },
    { id: 2, title: 'JavaScript Fatigue', tags: ['js', 'rant'], views: 9001 },
    { id: 3, title: 'The Perfect Deploy', tags: ['ops', 'ruby'], views: 500 }
  ])
end

# Query like you always wanted to:
popular_ruby_posts = rs(:posts)
  .where(tags: { contains: 'ruby' })
  .where(views: { greater_than: 1000 })
  .order(:views, desc: true)
  .all

puts popular_ruby_posts.first[:title]  # => "Why I Love Ruby"
```

That global `rs()` helper? It's there because life's too short to type `Risa.query()` every time.

---

## Data Sources: Choose Your Own Adventure

### Option 1: Inline Arrays (Perfect for Prototyping)

When you just need to get something working:

```ruby
Risa.define :users do
  from_array([
    { id: 1, name: 'Alice', role: 'admin', coffee_preference: 'black' },
    { id: 2, name: 'Bob', role: 'user', coffee_preference: 'latte' },
    { id: 3, name: 'Carol', role: 'editor', coffee_preference: 'espresso' }
  ])
end
```

### Option 2: File-Based Data (The Grown-Up Way)

Your data files are just Ruby scripts that return hashes. No parsing, no gotchas:

```ruby
# data/posts/001-hello-world.rb
{
  id: 1,
  title: 'Hello World',
  slug: 'hello-world',
  published_at: Date.new(2024, 1, 1),
  tags: ['ruby', 'beginnings'],
  meta: {
    author: 'You',
    reading_time: '2 min'
  }
}

# data/posts/002-advanced-stuff.rb
{
  id: 2,
  title: 'Advanced Ruby Wizardry',
  slug: 'advanced-ruby-wizardry',
  published_at: Date.new(2024, 1, 15),
  tags: ['ruby', 'advanced'],
  meta: {
    author: 'You (but smarter)',
    reading_time: '15 min'
  }
}
```

```ruby
Risa.define :posts do
  load 'posts/*.rb'  # Loads in sorted filename order
end

# Want a different data directory? No problem:
Risa.configure(data_path: 'content/data')
```

Pro tip: Your editor will syntax highlight these files, catch typos, and even provide autocomplete. Try doing that with YAML.

---

## Scopes: Make Your Queries Reusable

Remember writing the same `.where()` chains over and over? Those days are over:

```ruby
Risa.define :posts do
  from_array([...])  # Your data

  scope({
    published: -> { where(published: true) },
    featured: -> { where(featured: true) },
    recent: ->(n=10) { order(:published_at, desc: true).limit(n) },
    tagged: ->(tag) { where(tags: { contains: tag }) },
    popular: -> { where(views: { greater_than: 100 }).order(:views, desc: true) }
  })
end

# Now your queries read like English:
trending_ruby_posts = rs(:posts).published.tagged('ruby').popular.recent(5)
featured_content = rs(:posts).published.featured.recent
```

Scopes are chainable, composable, and parameterizable. They're basically custom query methods that don't suck.

---

## Querying: The Good Stuff

Risa provides a fluent, chainable API for filtering and sorting your data. Queries are lazy—they only execute when you ask for the results (e.g., by calling `.first`, `.map`, `.to_a`, `.each`, `.size`).

### Basic Queries (The Classics)

```ruby
posts = rs(:posts) # Get the query builder for :posts

# Get results
posts.to_a  # Get all matching records as an array of Risa::InstanceWrapper objects
posts.first # First match or nil
posts.last  # Last match (respects order) or nil
posts.count # Fast count of matching records

# Find by specific attribute(s)
posts.find_by(slug: 'hello-world') # Convenience for where(slug: '...').first
posts.find_by(id: 1)
```

**Note:** You no longer need to call `.all`. The query object itself acts like an array when you iterate (`.each`, `.map`) or access its size (`.size`, `.count`, `.length`). Use `.to_a` if you specifically need a plain `Array`.

### Where Clauses (AND Logic)

Chain multiple `.where` calls or provide multiple conditions in a hash to combine filters with `AND`.

```ruby
# Find published posts tagged 'ruby'
rs(:posts).where(published: true).where(tags: { contains: 'ruby' })

# Equivalent using a single hash
rs(:posts).where(published: true, tags: { contains: 'ruby' })
```

### OR Logic (`or_where`)

Use `.or_where` to add conditions combined with `OR`.

```ruby
# Find posts that are featured OR have more than 1000 views
rs(:posts).where(featured: true).or_where(views: { greater_than: 1000 })
# => WHERE featured = true OR views > 1000
```

### Grouping Conditions with Blocks

Use blocks with `where` and `or_where` to create nested logical groups. Conditions inside a block are implicitly joined by `AND` unless `or_where` is used within that block.

```ruby
# Find posts where (author_id = 1 AND published = true)
rs(:posts).where do |q|
  q.where(author_id: 1).where(published: true)
end

# Find posts where (author_id = 1 AND (published = true OR featured = true))
rs(:posts).where(author_id: 1).where do |q|
  q.where(published: true).or_where(featured: true)
end
# => WHERE author_id = 1 AND (published = true OR featured = true)

# Find posts where (author_id = 1 AND published = true) OR (views > 1000)
rs(:posts).where { |q| q.where(author_id: 1).where(published: true) }
           .or_where(views: { greater_than: 1000 })
# => WHERE (author_id = 1 AND published = true) OR views > 1000

# Find posts where (author_id = 1 AND published = true) OR (author_id = 2 AND featured = true)
rs(:posts).where { |q| q.where(author_id: 1).where(published: true) }
           .or_where { |q| q.where(author_id: 2).where(featured: true) }
# => WHERE (author_id = 1 AND published = true) OR (author_id = 2 AND featured = true)
```

### Operators & Negation (Hash Conditions)

Use hash conditions within `where` or `or_where` for powerful comparisons and negation.

```ruby
# Text searches
rs(:posts).where(title: { contains: 'Ruby' })
rs(:posts).where(title: { starts_with: 'How to' })
rs(:posts).where(title: { ends_with: '101' })

# Numeric comparisons
rs(:posts).where(views: { greater_than: 1000 })
rs(:posts).where(views: { less_than_or_equal: 500 })
rs(:posts).where(score: { from: 7.5, to: 9.0 }) # Inclusive range
rs(:posts).where(views: 100..500)             # Ruby Range works too

# Existence and emptiness
rs(:posts).where(featured_image: { exists: true })  # Key is present and not nil
rs(:posts).where(featured_image: { exists: false }) # Key is missing or nil
rs(:posts).where(tags: { empty: false })           # Not nil, not '', not []
rs(:posts).where(tags: { empty: true })            # Is nil, '', or []

# Array / Set operations
rs(:posts).where(id: { in: [1, 3, 5] })        # Value is one of these
rs(:posts).where(id: [1, 3, 5])               # Shortcut for :in
rs(:posts).where(status: { not_in: ['draft', 'archived'] }) # Value is NOT one of these
rs(:posts).where(tags: ['ruby', 'web'])      # Exact array match (order matters)

# Negation
rs(:posts).where(published: { not: true })     # Value is not true (false or nil)
rs(:posts).where(title: { not: 'Hello' })      # Value is not 'Hello'
rs(:posts).where(views: { not: nil })         # Same as { exists: true }
```

### Ordering (Nil-Safe and Type-Aware)

Sort your results using `.order`. Nils are always sorted last.

```ruby
# Ascending (default)
rs(:posts).order(:published_at)

# Descending
rs(:posts).order(:views, desc: true)

# Strings sort naturally
rs(:posts).order(:title)
```

Mixed types? No problem. Risa handles the type coercion so you don't have to think about it during sorting.

-----
### Limiting and Pagination

```ruby
# Classic pagination
rs(:posts).limit(10)                    # First 10
rs(:posts).offset(20).limit(10)         # Items 21-30

# Modern pagination with metadata
pages = rs(:posts).order(:created_at, desc: true).paginate(per_page: 5)

page = pages.first
page.items         # Array of posts for this page
page.current_page  # 1
page.total_pages   # 4
page.total_items   # 18
page.next_page     # 2 (or nil if last page)
page.prev_page     # nil (or previous page number)
page.is_first_page # true
page.is_last_page  # false

# Perfect for building pagination UI
pages.each do |page|
  puts "Page #{page.current_page}: #{page.items.size} posts"
end
```

The Page object has everything you need for pagination UI without any mental math.

---

## Instance Wrappers: Hash-Like, But Better

Results aren't plain hashes—they're immutable wrappers that feel like hashes but prevent accidents:

```ruby
post = rs(:posts).first

# Access like a hash (symbol or string keys both work)
post[:title]        # => "Hello World"
post['title']       # => "Hello World" (same thing)

# All the hash methods you expect
post.keys           # => [:id, :title, :content, ...]  
post.size           # => 5
post.has_key?(:id)  # => true
post.include?('title') # => true
post.to_h           # Raw hash if you need it

# But immutable (this raises an error)
post[:title] = 'New Title'  # RuntimeError: collections are immutable

# Custom methods work too
post.excerpt(20)    # Your custom methods
post.reading_time   # Computed properties
```

It's like getting a hash that went to finishing school.

---

## Development Helpers (For Your Sanity)

```ruby
# Reload everything during development
Risa.reload

# See what models you've defined
Risa.defined_models  # => [:posts, :users, :tags]

# Use the explicit API when you need it
Risa.query(:posts).where(...)  # Same as rs(:posts).where(...)
```

Error messages are actually helpful:
- Syntax errors in data files show the exact file and line
- Missing files tell you the exact pattern that failed
- Type errors explain what was expected vs. what was found

---

## Relationships: Connecting Your Data

Risa makes it easy to define relationships between your data collections, similar to ActiveRecord associations. Define them right inside your `Risa.define` block.

### Defining Relationships

Use `belongs_to`, `has_many`, and `has_one` to link your data. Risa uses conventions for keys but allows overrides.

```ruby
# --- Authors ---
Risa.define :authors do
  from_array([
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' }
  ])

  # Author has many posts (looks for :author_id in :posts)
  has_many :posts

  # Author has one profile (looks for :author_id in :profiles)
  has_one :profile
end

# --- Posts ---
Risa.define :posts do
  from_array([
    { id: 101, title: 'Intro to Risa', author_id: 1 },
    { id: 102, title: 'Advanced Ruby', author_id: 1 },
    { id: 103, title: 'Web Development', author_id: 2 }
  ])

  # Post belongs to an author (looks for :author_id here, links to :authors using :id)
  belongs_to :author
end

# --- Profiles ---
Risa.define :profiles do
  from_array([
    { profile_id: 201, bio: 'Ruby Developer', author_id: 1 }, # Note: primary key is :profile_id
    { profile_id: 202, bio: 'Web Enthusiast', author_id: 2 }
  ])

  # Profile belongs to an author (looks for :author_id here)
  # Target model (:authors) uses :id as primary key by default
  belongs_to :author
end
```

### Accessing Relationships

Access related data using simple dot notation on your `Risa::InstanceWrapper` objects.

```ruby
alice = rs(:authors).find_by(id: 1)
post = rs(:posts).find_by(id: 101)
profile = rs(:profiles).find_by(profile_id: 201)

# Belongs To (returns InstanceWrapper or nil)
author_name = post.author.name
# => "Alice"
author_bio = profile.author.profile.bio # Chain through relations
# => "Ruby Developer"

# Has One (returns InstanceWrapper or nil)
alices_bio = alice.profile.bio
# => "Ruby Developer"

# Has Many (returns a Risa::Query object)
alices_posts = alice.posts
# => <Risa::Query @model_name=:posts ...>

# You can chain queries on has_many results
published_titles = alice.posts.where(published: true).map { |p| p.title }
# => ["Intro to Risa"]
```

### Overriding Conventions

Need custom keys or class names? No problem.

```ruby
Risa.define :users do
  from_array([{ user_pk: 501, username: 'admin' }]) # Custom primary key

  # Specify foreign_key in posts (:creator_id) and owner_key here (:user_pk)
  has_many :articles, class_name: :posts, foreign_key: :creator_id, owner_key: :user_pk
end

Risa.define :posts do
  # ... other posts ...
  from_array([{ id: 105, title: 'Admin Post', creator_id: 501 }]) # Custom foreign key

  # Specify foreign_key here (:creator_id) and primary_key on users (:user_pk)
  belongs_to :creator, class_name: :users, foreign_key: :creator_id, primary_key: :user_pk
end

admin = rs(:users).first
admin_article_title = admin.articles.first.title
# => "Admin Post"

post = rs(:posts).find_by(id: 105)
creator_name = post.creator.username
# => "admin"
```

### Many-to-Many (`has_many :through`)

Define the intermediate `has_many` first, then the `through` relationship.

```ruby
Risa.define :posts do
  # ... (fields, belongs_to :author) ...
  has_many :post_tags # Link to the join collection
  has_many :tags, through: :post_tags # Go through :post_tags to find :tags
                                      # (infers :tag on PostTag model)
end

Risa.define :tags do
  from_array([ { id: 301, name: 'ruby' }, { id: 302, name: 'web' } ])
  has_many :post_tags
  has_many :posts, through: :post_tags # Go through :post_tags to find :posts
                                       # (infers :post on PostTag model)
end

Risa.define :post_tags do # The join collection
  from_array([
    { id: 401, post_id: 101, tag_id: 301 },
    { id: 402, post_id: 101, tag_id: 302 },
    { id: 403, post_id: 102, tag_id: 301 }
  ])
  belongs_to :post # Link back to posts
  belongs_to :tag  # Link back to tags
end

# Usage:
post = rs(:posts).find_by(id: 101)
tag_names = post.tags.map { |t| t.name }
# => ["ruby", "web"]

tag = rs(:tags).find_by(name: 'ruby')
post_titles = tag.posts.map { |p| p.title }
# => ["Intro to Risa", "Advanced Ruby"]

# Override source if needed:
# has_many :categories, through: :post_categories, source: :category
```

Relationships in Risa provide a powerful yet simple way to navigate your connected data directly within Ruby.

---

## Presenters: Adding Behavior to Your Data

While `Risa` focuses on querying, you often need helper methods for formatting or deriving information from your data records. Instead of cluttering your view logic, you can define these directly using `Risa.present`. This replaces the older, less ergonomic `item` block.

### Defining Presenter Methods

Use standard Ruby `def` syntax within a `Risa.present` block associated with your model name. Inside these methods, `self` refers to the `Risa::InstanceWrapper` object, allowing you to access the underlying data using `self[:key]` or just `key` (if the key doesn't clash with a method name).

```ruby
Risa.define :posts do
  from_array([
    { id: 1, title: 'Hello World', slug: 'hello-world', content: 'This is the first post.', published_at: Date.today }
  ])
  belongs_to :author # Example relation
end

# Define presenter methods for the :posts model
Risa.present :posts do
  # Simple formatting
  def formatted_date
    self[:published_at]&.strftime('%B %d, %Y') # Access data with self[:key]
  end

  # Derived data
  def url
    "/posts/#{slug}/" # Access data directly via dynamically defined method 'slug'
  end

  # Methods with arguments
  def excerpt(word_count = 25)
    words = content.split # Access data via 'content' method
    return content if words.size <= word_count
    words.take(word_count).join(' ') + '...'
  end

  # Accessing relations within presenters
  def author_name
    author&.name || 'Anonymous' # Call the 'author' relation method
  end
end
```

### Using Presenter Methods

Presenter methods are automatically available directly on the `InstanceWrapper` objects returned by your queries.

```ruby
post = rs(:posts).first

# Access hash data keys
puts post.id       # => 1
puts post[:title]  # => "Hello World" (Hash access still works)

# Call presenter methods
puts post.url            # => "/posts/hello-world/"
puts post.formatted_date # => "October 27, 2025"
puts post.excerpt(3)     # => "This is the..."
puts post.author_name    # => (Assuming author relation works) "Alice" or "Anonymous"
```

### Benefits

  * **Clean Ruby Syntax:** Uses standard `def`
  * **Clear Separation:** Keeps presentation logic separate from the core data definition (`Risa.define`).
  * **Precedence:** Presenter methods will override accessor methods created for hash keys if they share the same name. Access the original hash value using `self[:key]` if needed.

Use `Risa.present` to keep your data definitions clean and add reusable display logic directly to your data objects.

---

## Auto-Loading Data Files

Instead of manually requiring data files, use `Risa.load_from` to automatically discover and load all data definitions:

```ruby
# Directory structure:
# data/
#   users.rb
#   posts.rb
#   categories.rb

# config.ru or boot file
require 'hr'

Risa.load_from('data')  # Loads all .rb files in data/

# Now all collections are available
rs(:users).where(active: true)
rs(:posts).order(:created_at)
```

**Development mode reloading:**

```ruby
if ENV['RACK_ENV'] == 'development'
  require 'listen'
  
  listener = Listen.to('data') do |modified, added, removed|
    puts "Data changed, reloading..."
    Risa.reload_from('data')
  end
  listener.start
end
```

Files are loaded in alphabetical order. Use nested directories to organize large data sets:

```ruby
data/
  blog/
    posts.rb
    categories.rb
  users/
    admins.rb
    customers.rb

Risa.load_from('data')  # Loads everything recursively
```

---

## Performance Notes (For the Curious)

**The Good News:** Risa is fast enough for most use cases. We're talking thousands of items with complex queries in milliseconds.

**The Technical Details:**
- Everything lives in memory (no I/O after initial load)
- Queries are lazy—filters only apply when you call `.all`, `.first`, etc.
- Data is frozen at load time (immutable and thread-safe)
- Method results are memoized automatically
- Under 500 lines of core code (minimal overhead)

**Sweet Spot:** Hundreds to low thousands of items. Perfect for:
- Blog posts and pages
- Product catalogs  
- Team directories
- Configuration data
- Documentation sites
- Prototype datasets

**When to Graduate to a Real Database:**
- Tens of thousands of items
- Real-time updates needed
- Complex relationships and joins
- Multi-user concurrent writes

---

## When Risa Shines

**Perfect For:**
- Static site content management
- Rapid prototyping with structured data  
- Configuration and settings management
- Small-to-medium datasets that don't change often
- Replacing hand-rolled JSON/YAML parsers
- When you want SQL-like querying without SQL complexity

**Not Ideal For:**
- Large-scale data (stick with SQLite/PostgreSQL/MySQL)
- Real-time analytics
- Data that changes frequently
- Multi-table joins and complex relationships  
- When you actually need ACID transactions

---

## The Philosophy

We built Risa because we were tired of the false choice between "simple but limited" and "powerful but complex." 

Why should prototyping with structured data require setting up a database? Why should static sites need a complex build pipeline just to query some content? Why can't data files be as expressive as the rest of our Ruby code?

Risa is our answer: a data layer that grows with your project. Start with arrays, move to files, add scopes and methods as needed. When you outgrow it, you'll have learned exactly what you need from a real database.

It's the tool we always wished existed. Now it does.

---

**Ready to feel the joy of simple, powerful data?**

```bash
gem install hr
```

Your future self will thank you.