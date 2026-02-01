# Gemfile.cgi (CGI環境下で動かすためのGemfile)
source "https://rubygems.org"

# Sinatra 4.0以降はRack 3が必須になるため、Rack 2を使うなら3系で止める必要があります
gem "sinatra", "~> 3.2"

# XREA等のCGI環境ではRack 3系(CGIハンドラ削除等)は鬼門なので、2系に固定するのは大正解です
gem "rack", "~> 2.2"

# データベース利用
gem "sqlite3"

