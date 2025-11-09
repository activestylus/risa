# frozen_string_literal: true
module Risa
  class Page
    attr_reader :items, :current_page, :total_pages, :total_items,
                :prev_page, :next_page, :is_first_page, :is_last_page
    
    def initialize(items, current_page, total_pages, total_items)
      @items = items
      @current_page = current_page
      @total_pages = total_pages
      @total_items = total_items
      @prev_page = current_page > 1 ? current_page - 1 : nil
      @next_page = current_page < total_pages ? current_page + 1 : nil
      @is_first_page = current_page == 1
      @is_last_page = current_page == total_pages
    end
    
    # Aliases for consistency with your SSG (e.g., 'posts' instead of 'items')
    alias_method :posts, :items
    
    def to_h
      {
        items: @items,
        current_page: @current_page,
        total_pages: @total_pages,
        total_items: @total_items,
        prev_page: @prev_page,
        next_page: @next_page,
        is_first_page: @is_first_page,
        is_last_page: @is_last_page
      }
    end
  end
end