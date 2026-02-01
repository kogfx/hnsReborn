#!/usr/local/bin/ruby
# ↑ レンタルサーバーのRubyのパスに合わせて書き換えてください (例: /usr/bin/ruby)

# エラーをブラウザに表示させる（デバッグ用・本番では消しても良い）
require 'cgi'

begin
  # 環境変数の調整 (Bundler用)
  ENV['BUNDLE_GEMFILE'] ||= File.expand_path('./Gemfile', __dir__)
  
  require 'rubygems'
  require 'bundler/setup'

  # RackのCGIハンドラを読み込む
  require 'rack'
  require 'rack/handler/cgi'

  # あなたのアプリを読み込む
  require_relative 'app'

  # CGIとしてSinatraアプリを起動
  Rack::Handler::CGI.run Sinatra::Application

rescue => e
  # エラーが起きたら画面に出す
  cgi = CGI.new
  print cgi.header('type' => 'text/html')
  puts "<h1>500 Internal Server Error</h1>"
  puts "<pre>#{e.class}: #{e.message}"
  puts e.backtrace.join("\n")
  puts "</pre>"
end
