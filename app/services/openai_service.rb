class OpenaiService
  class << self
    # OpenAI APIを使ってテキスト生成
    def generate_text(prompt:, model: 'gpt-3.5-turbo', max_tokens: 200, temperature: 0.7)
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: model,
          messages: [{ role: 'user', content: prompt }],
          max_tokens: max_tokens,
          temperature: temperature
        }
      )

      response.dig('choices', 0, 'message', 'content')&.strip
    rescue StandardError => e
      Rails.logger.error "OpenAI API Error: #{e.message}"
      nil
    end

    # エラーハンドリング付きのリトライ機能
    def generate_text_with_retry(prompt:, model: 'gpt-3.5-turbo', max_tokens: 200, temperature: 0.7, retries: 2)
      attempt = 0

      begin
        attempt += 1
        generate_text(prompt: prompt, model: model, max_tokens: max_tokens, temperature: temperature)
      rescue StandardError => e
        if attempt <= retries
          Rails.logger.warn "OpenAI API retry #{attempt}/#{retries}: #{e.message}"
          sleep(1 * attempt) # 指数バックオフ
          retry
        else
          Rails.logger.error "OpenAI API failed after #{retries} retries: #{e.message}"
          nil
        end
      end
    end
  end
end