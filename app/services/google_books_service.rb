require 'net/http'
require 'json'
require 'uri'

class GoogleBooksService
  BASE_URL = 'https://www.googleapis.com/books/v1/volumes'
  
  class << self
    def search_by_isbn(isbn, max_results: nil)
      return nil if isbn.blank?
      
      # ISBN-10またはISBN-13の形式を検証
      clean_isbn = clean_isbn_format(isbn)
      return nil unless valid_isbn?(clean_isbn)
      
      query = "isbn:#{clean_isbn}"
      search_books(query, max_results: max_results)
    end
    
    def search_by_title(title, author: nil, max_results: nil)
      return nil if title.blank?
      
      # 部分一致検索のため、intitleとinauthorを使わずに通常の検索を使用
      query_parts = []
      query_parts << title.strip
      query_parts << author.strip if author.present?
      
      query = query_parts.join(" ")
      search_books(query, max_results: max_results)
    end
    
    def get_book_by_id(google_books_id)
      return nil if google_books_id.blank?
      
      begin
        uri = URI("#{BASE_URL}/#{google_books_id}")
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          parse_single_book(JSON.parse(response.body))
        else
          Rails.logger.error "Google Books API error: #{response.code} - #{response.body}"
          nil
        end
      rescue => e
        Rails.logger.error "Google Books API connection error: #{e.message}"
        nil
      end
    end
    
    private
    
    def search_books(query, max_results: nil)
      all_results = []
      start_index = 0
      max_per_request = 40  # Google Books APIの最大値
      max_total_results = max_results || 1000  # デフォルトで最大1000件
      
      begin
        loop do
          remaining_results = max_total_results - all_results.length
          break if remaining_results <= 0
          
          current_max = [max_per_request, remaining_results].min
          
          uri = URI(BASE_URL)
          uri.query = URI.encode_www_form(
            q: query, 
            maxResults: current_max,
            startIndex: start_index
          )
          
          response = Net::HTTP.get_response(uri)
          
          if response.code == '200'
            data = JSON.parse(response.body)
            current_results = parse_search_results(data)
            
            break if current_results.empty?
            
            all_results.concat(current_results)
            
            # totalItemsが利用可能な場合はそれを使用
            total_items = data['totalItems'] || 0
            break if all_results.length >= total_items || current_results.length < current_max
            
            start_index += current_max
          else
            Rails.logger.error "Google Books API error: #{response.code} - #{response.body}"
            break
          end
        end
        
        all_results
      rescue => e
        Rails.logger.error "Google Books API connection error: #{e.message}"
        all_results.empty? ? [] : all_results
      end
    end
    
    def parse_search_results(data)
      return [] unless data['items']
      
      data['items'].map { |item| parse_single_book(item) }.compact
    end
    
    def parse_single_book(item)
      volume_info = item['volumeInfo'] || {}
      industry_identifiers = volume_info['industryIdentifiers'] || []
      
      # ISBN-10とISBN-13を分離
      isbn_10 = find_isbn(industry_identifiers, 'ISBN_10')
      isbn_13 = find_isbn(industry_identifiers, 'ISBN_13')
      
      # 画像URLを取得（高画質を優先）
      image_links = volume_info['imageLinks'] || {}
      image_url = image_links['large'] || 
                  image_links['medium'] || 
                  image_links['small'] || 
                  image_links['thumbnail'] || 
                  image_links['smallThumbnail']
      
      {
        google_books_id: item['id'],
        title: volume_info['title'],
        author: (volume_info['authors'] || []).join(', '),
        publisher: volume_info['publisher'],
        published_date: volume_info['publishedDate'],
        description: volume_info['description'],
        isbn_10: isbn_10,
        isbn_13: isbn_13,
        image_url: image_url,
        page_count: volume_info['pageCount'],
        language: volume_info['language'],
        categories: (volume_info['categories'] || []).join(', ')
      }
    end
    
    def find_isbn(identifiers, type)
      identifier = identifiers.find { |id| id['type'] == type }
      identifier ? identifier['identifier'] : nil
    end
    
    def clean_isbn_format(isbn)
      # ハイフンや空白を除去
      isbn.to_s.gsub(/[-\s]/, '')
    end
    
    def valid_isbn?(isbn)
      # ISBN-10: 10桁の数字（最後の桁はXも可）
      # ISBN-13: 13桁の数字
      isbn.match?(/\A\d{9}[\dX]\z/) || isbn.match?(/\A\d{13}\z/)
    end
  end
end