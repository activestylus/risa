require_relative 'test_helper'

module Risa
  class DataLoaderTest < Minitest::Test
    def setup
      @test_dir = File.join(Dir.tmpdir, "risa_test_#{Process.pid}_#{Time.now.to_i}")
      FileUtils.mkdir_p(@test_dir)
    end

    def teardown
      FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
      Risa.reload  # Clear any test data
    end

    def test_load_from_loads_data_files
      create_data_file('users.rb', <<~RUBY)
        Risa.define :users do
          from_array([
            { id: 1, name: 'Alice' },
            { id: 2, name: 'Bob' }
          ])
        end
      RUBY

      Risa.load_from(@test_dir)

      assert_equal 2, rs(:users).count
      assert_equal 'Alice', rs(:users).first[:name]
    end

    def test_load_from_handles_multiple_files
      create_data_file('users.rb', <<~RUBY)
        Risa.define :users do
          from_array([{ id: 1, name: 'Alice' }])
        end
      RUBY

      create_data_file('posts.rb', <<~RUBY)
        Risa.define :posts do
          from_array([{ id: 101, title: 'Hello' }])
        end
      RUBY

      Risa.load_from(@test_dir)

      assert_equal 1, rs(:users).count
      assert_equal 1, rs(:posts).count
    end

    def test_reload_from_reloads_changed_data
      create_data_file('users.rb', <<~RUBY)
        Risa.define :users do
          from_array([{ id: 1, name: 'Alice' }])
        end
      RUBY

      Risa.load_from(@test_dir)
      assert_equal 1, rs(:users).count

      # Change the data file
      create_data_file('users.rb', <<~RUBY)
        Risa.define :users do
          from_array([
            { id: 1, name: 'Alice' },
            { id: 2, name: 'Bob' }
          ])
        end
      RUBY

      Risa.reload_from(@test_dir)
      assert_equal 2, rs(:users).count
    end

    def test_load_from_handles_nested_directories
      FileUtils.mkdir_p(File.join(@test_dir, 'blog'))
      
      create_data_file('blog/posts.rb', <<~RUBY)
        Risa.define :blog_posts do
          from_array([{ id: 1, title: 'Post' }])
        end
      RUBY

      Risa.load_from(@test_dir)

      assert_equal 1, rs(:blog_posts).count
    end

    private

    def create_data_file(path, content)
      file_path = File.join(@test_dir, path)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, content)
    end
  end
end