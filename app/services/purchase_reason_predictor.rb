class PurchaseReasonPredictor
  # 学習段階の定義
  LEARNING_STAGES = {
    stage_1: { range: 1..1, personal_weight: 0, general_weight: 100 },      # 1冊目: 一般的なデータのみ
    stage_2: { range: 2..3, personal_weight: 30, general_weight: 70 },      # 2-3冊目: 個人30% + 一般70%
    stage_3: { range: 4..Float::INFINITY, personal_weight: 80, general_weight: 20 }  # 4冊目以上: 個人80% + 一般20%
  }.freeze

  # 一般的なパターン例
  GENERAL_PATTERNS = [
    "仕事のスキルアップのため",
    "新しい知識を身につけたかった",
    "友人に勧められた",
    "趣味で読みたいと思った",
    "話題の本だったから",
    "レビューが良かったので購入した"
  ].freeze

  class << self
    # メイン処理: 購入理由を推測
    def predict(user:, book_title:, book_author: nil, book_description: nil)
      # ユーザーの登録冊数を取得
      user_book_count = user.books.count

      # 学習段階を判定
      stage = determine_stage(user_book_count + 1) # +1は今回追加する本を含むため

      # プロンプトを構築
      prompt = build_prompt(
        user: user,
        book_title: book_title,
        book_author: book_author,
        book_description: book_description,
        stage: stage
      )

      # OpenAI APIを呼び出し
      predicted_reason = OpenaiService.generate_text_with_retry(
        prompt: prompt,
        max_tokens: 150,
        temperature: 0.7
      )

      predicted_reason || fallback_reason(stage)
    end

    private

    # 学習段階を判定
    def determine_stage(book_number)
      LEARNING_STAGES.each do |stage_name, config|
        return stage_name if config[:range].include?(book_number)
      end
      :stage_3 # デフォルトは最終段階
    end

    # プロンプトを構築（段階別に重み付け）
    def build_prompt(user:, book_title:, book_author:, book_description:, stage:)
      config = LEARNING_STAGES[stage]

      prompt = "以下の本について、ユーザーが購入した理由を日本語で1文で簡潔に推測してください。\n\n"

      # 本の情報
      prompt += "【本の情報】\n"
      prompt += "タイトル: #{book_title}\n"
      prompt += "著者: #{book_author}\n" if book_author.present?
      prompt += "説明: #{book_description}\n" if book_description.present?
      prompt += "\n"

      # 一般的なデータを含める
      if config[:general_weight] > 0
        prompt += "【一般的なパターン例（参考）】\n"
        prompt += GENERAL_PATTERNS.join("\n")
        prompt += "\n\n"
      end

      # 個人データを含める（段階が進んだら）
      if config[:personal_weight] > 0
        user_past_reasons = fetch_user_past_reasons(user)
        if user_past_reasons.present?
          prompt += "【このユーザーの過去の購入理由（参考）】\n"
          prompt += user_past_reasons.join("\n")
          prompt += "\n\n"
        end
      end

      # 指示
      prompt += "
上記の情報を参考に、このユーザーの購入理由を（50文字以内で）簡潔に推測してください。"

      prompt
    end

    # ユーザーの過去の購入理由を取得
    def fetch_user_past_reasons(user)
      user.books
          .where.not(purchase_reason: [nil, ''])
          .order(created_at: :desc)
          .limit(5)
          .pluck(:purchase_reason)
    end

    # フォールバック理由（API失敗時）
    def fallback_reason(stage)
      case stage
      when :stage_1
        GENERAL_PATTERNS.sample
      when :stage_2
        "新しい知識を身につけたかった"
      when :stage_3
        "過去の傾向から判断した理由"
      end
    end
  end
end
