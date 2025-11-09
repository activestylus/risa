
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.2] - 2025-11-09

### 💥 Changed
* Updated the `rs()` helper for the more idiomatic `all()` helper

## [1.0.1] - 2025-11-01

### 🐛 Fixed
* Fixed a bug where using `.or_where` as the very first clause in a query chain would fail.
* Ensured `.count` and `.size` correctly respect any applied `.limit()` and `.offset()` chains.

## [1.0.0] - 2025-10-28

This is the first stable 1.0 release! It introduces auto-loading and finalizes the presenter and relationship APIs.

### ✨ Added
* **`Risa.load_from(directory_path)`:** A new, convenient way to auto-load all data definitions from a specified directory (e.g., `data/`).
* **`Risa.reload_from(directory_path)`:** A helper for development to reload all definitions, perfect for use with tools like `listen`.

### 💥 Changed
* Query results (`Risa::InstanceWrapper` objects) are now fully **immutable** and **frozen** to prevent accidental mutation and improve thread-safety.
* Improved type-coercion in `.order` to more robustly handle sorting columns with mixed data types (e.g., `Integer` and `String`).

### ⛔ Removed
* Removed the deprecated `item { ... }` block inside `Risa.define`. Please use the new `Risa.present(:model_name) { ... }` API introduced in `0.9.0`.

## [0.9.0] - 2025-10-05

### ✨ Added
* **New Presenter API:** Introduced `Risa.present(:model_name) { ... }` as the new, cleaner way to define presenter methods. This uses standard `def` syntax and keeps presentation logic separate from data definition.
* Instance wrappers now dynamically define accessor methods for all hash keys (e.g., `post.title`), which can be used within presenter methods. Presenter methods take precedence over key accessors.
* Added `Risa.reload` helper for hot-reloading data in development environments.

### ⚠️ Deprecated
* The `item { ... }` block within `Risa.define` is now deprecated in favor of `Risa.present`. It will be removed in version 1.0.

## [0.8.0] - 2025-09-15

### ✨ Added
* **Pagination:** Added `.limit()` and `.offset()` for basic pagination.
* **Advanced Pagination:** Introduced the `.paginate(per_page: N)` method. This returns an enumerable `Risa::Page` object with helpers like `.current_page`, `.total_pages`, `.total_items`, `.next_page`, `.prev_page`, `is_first_page?`, and `is_last_page?`.

## [0.7.0] - 2025-08-25

### ✨ Added
* **Many-to-Many Relationships:** Added support for `has_many :through` relationships.

### 🐛 Fixed
* `belongs_to` relationships now correctly return `nil` if the foreign key is missing or `nil`, rather than raising an error.
* `has_many` relationships now correctly work with custom `primary_key` definitions on the target model.

## [0.6.0] - 2025-07-30

### ✨ Added
* **Relationships:** Initial support for data relationships!
    * `belongs_to`
    * `has_many`
    * `has_one`
* Relationships support overrides for `class_name`, `foreign_key`, `primary_key`, and `owner_key`.
* Related objects are returned as `Risa::InstanceWrapper` (`belongs_to`, `has_one`) or a new chainable `Risa::Query` (`has_many`).

## [0.5.0] - 2025-07-10

### ✨ Added
* **`OR` Logic:** Added `.or_where` for building `OR` queries.
* **Grouped Conditions:** Added block support to `where` and `or_where` for creating nested logical groups (e.g., `where { |q| q.where(a: 1).or_where(b: 2) }`).
* **New Operators:** Added new hash condition operators:
    * `:not` (e.g., `where(published: { not: true })`)
    * `:in` and `:not_in` (e.g., `where(id: { in: [1, 3, 5] })`)
    * `:exists` (for non-nil values)
    * `:empty` (for `nil`, `""`, or `[]`)

## [0.4.0] - 2025-06-15

### ✨ Added
* **Advanced `where` Operators:** `where` now supports more than just simple equality.
    * `:greater_than` / `:gt`
    * `:less_than` / `:lt`
    * `:greater_than_or_equal` / `:gte`
    * `:less_than_or_equal` / `:lte`
    * `:contains` (for strings and arrays)
    * `:starts_with` and `:ends_with` (for strings)
* **Ranges:** `where` now accepts a Ruby `Range` (e.g., `where(views: 100..500)`).
* **Ordering:** `.order` now accepts a second argument, `desc: true`, for descending sorts.
* **Helpers:** Added `.find_by(...)` as a shortcut for `.where(...).first`.

### 🐛 Fixed
* `.order` now gracefully handles mixed-type comparisons (e.g., `String` and `Date`) without crashing.

## [0.3.0] - 2025-05-20

### ✨ Added
* **Scopes:** Added support for reusable query scopes via `scope({...})` inside the `Risa.define` block.
* Scopes can accept arguments (e.g., `scope recent: ->(n=5) { order(:created_at, desc: true).limit(n) }`).
* Scopes are chainable with `where`, `order`, and other scopes.

## [0.2.1] - 2025-05-01

### 🐛 Fixed
* `load` glob pattern now sorts files alphabetically before loading to ensure a predictable and consistent data order.
* `Risa.configure` now correctly resolves paths relative to the application root.

## [0.2.0] - 2025-04-25

### ✨ Added
* **File-Based Data:** Added `load 'path/to/*.rb'` loader. Data can now be loaded from individual Ruby files that return a hash.
* Added `Risa.configure(data_path: '...')` to set a base directory for data files.
* Added `Risa.defined_models` to inspect which models have been registered.

### 💥 Changed
* `Risa.define` is now lazy. Data from files is not loaded into memory until the first query is performed on that model.

## [0.1.1] - 2025-04-12

### 🐛 Fixed
* Fixed a `NoMethodError` when using `.order` on a key where some records had a `nil` value. Nils are now always sorted last by default.
* `all(:model).first` on an empty dataset now correctly returns `nil` instead of raising an error.

## [0.1.0] - 2025-04-10

### ✨ Added
* **Initial Release!**
* `Risa.define(:model_name)` block.
* `from_array([...])` data source.
* Global `all()` helper for easy querying.
* Basic `.where(key: value)` for exact matching.
* `.order(:key)` for ascending sort.
* Query execution methods: `.to_a`, `.first`, `.last`, `.each`.
* Results are wrapped in `Risa::InstanceWrapper` for hash-like access (`record[:key]`).