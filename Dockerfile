# 開発用Dockerfile - シンプル構成
FROM ruby:3.2.2

# 必要なパッケージをインストール
RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      libpq-dev \
      libvips \
      git \
      curl \
      nodejs \
      npm && \
    rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /rails

# 開発環境の設定
ENV RAILS_ENV=development
ENV BUNDLE_PATH="/usr/local/bundle"

# Gemfileをコピーしてbundle install
COPY Gemfile Gemfile.lock ./
RUN bundle install

# アプリケーションコードをコピー
COPY . .

# ポートを公開
EXPOSE 3000

# デフォルトコマンド（開発用）
CMD ["rails", "server", "-b", "0.0.0.0"]