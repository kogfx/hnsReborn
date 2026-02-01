# hnsReborn - Hyper Nikki System Reborn
# Copyright (c) 2026 kogfx (@kogfx)
# Released under the MIT License.
require 'sinatra'
require 'json'
require 'securerandom'
require 'fileutils'
require 'yaml'
require 'erb'
require 'pathname'
require 'sqlite3'
require 'date'
require_relative 'hnf_parser'
require_relative 'auth_manager'

# --- 設定読み込み ---
BASE_DIR = File.expand_path(__dir__)
config_path = File.join(BASE_DIR, 'config.yml')
config_content = File.read(config_path)
CONFIG = YAML.load(ERB.new(config_content).result)

DIARY_ROOT = File.expand_path(CONFIG['diary_root'], BASE_DIR)
CACHE_ROOT = CONFIG['cache_root'] ? File.expand_path(CONFIG['cache_root'], BASE_DIR) : DIARY_ROOT
DB_PATH    = CONFIG['db_path']    ? File.expand_path(CONFIG['db_path'], BASE_DIR)    : File.join(DIARY_ROOT, 'search.db')

DAYS_SHOWN = CONFIG['days_shown'] || 3
INDEX_DAYS = CONFIG['index_days'] || 14
PIM_FILES = {
  schedule: CONFIG['pim_schedule'],
  todo:     CONFIG['pim_todo'],
  link:     CONFIG['pim_link']
}
PARTS_FILES = {
  head: CONFIG['file_head'],
  foot: CONFIG['file_foot']
}

set :host_authorization, { permitted_hosts: [] }
set :port, CONFIG['port'] || 4567
set :bind, '0.0.0.0'
set :public_folder, 'public'

AUTH_MANAGER = AuthManager.new(DIARY_ROOT)

# --- Helper Methods ---

def current_ruri
  request.cookies['hns_ruri'] || params[:ruri]
end

def ensure_ruri
  ruri = current_ruri
  unless ruri
    ruri = "RURI" + SecureRandom.alphanumeric(12)
    response.set_cookie('hns_ruri', {
      value: ruri,
      path: '/',
      expires: Time.now + (60 * 60 * 24 * 365 * 10)
    })
  end
  ruri
end

def is_admin?
  ruri = current_ruri
  return false if ruri.nil? || ruri.empty?
  auth_file = File.join(DIARY_ROOT, 'conf', 'auth_ruri.txt')
  return false unless File.exist?(auth_file)
  valid_ruris = File.readlines(auth_file).map(&:strip)
  valid_ruris.include?(ruri)
end

def valid_ruri?(ruri)
  return false if ruri.nil? || ruri.empty?
  auth_file = File.join(DIARY_ROOT, 'conf', 'auth_ruri.txt')
  return false unless File.exist?(auth_file)
  File.foreach(auth_file) do |line|
    next if line =~ /^#/ || line.strip.empty?
    registered_ruri = line.split(/\s|:/).first
    return true if registered_ruri == ruri
  end
  false
end

def visible_section?(section, ruri)
  return true if section[:visibility] == 'public'
  AUTH_MANAGER.can_view?(section[:group], ruri)
end

def find_diary_files(year, month, day, limit)
  all_files = Dir.glob(File.join(DIARY_ROOT, "**", "d*.hnf")).sort.reverse
  target_date_str = sprintf("%04d%02d%02d", year, month, day)
  start_index = all_files.find_index { |f| 
    fname = File.basename(f)
    if fname =~ /d(\d{8})\.hnf/
      $1 <= target_date_str
    else
      false
    end
  }
  return [] unless start_index
  all_files[start_index, limit]
end

def process_diary_file(hnf_path, user_ruri)
  relative_path = Pathname.new(hnf_path).relative_path_from(Pathname.new(DIARY_ROOT)).to_s
  json_relative_path = relative_path.sub(/\.hnf$/i, '.json')
  json_path = File.join(CACHE_ROOT, json_relative_path)
  json_dir = File.dirname(json_path)
  FileUtils.mkdir_p(json_dir) unless File.exist?(json_dir)

  filename = File.basename(hnf_path, ".*")
  date_match = filename.match(/d(\d{4})(\d{2})(\d{2})/)
  return nil unless date_match

  y = date_match[1].to_i
  m = date_match[2].to_i
  d = date_match[3].to_i
  display_date = "#{date_match[1]}/#{date_match[2]}/#{date_match[3]}"
  wdays = %w(日 月 火 水 木 金 土)
  week_day = wdays[Date.new(y, m, d).wday]

  if !File.exist?(json_path) || File.mtime(hnf_path) > File.mtime(json_path)
    begin
      data = HnfParser.parse_file(hnf_path)
      data[:meta][:generated_at] = Time.now.to_s
      File.write(json_path, data.to_json)
    rescue => e
      return { error: "Parse error in #{filename}: #{e.message}" }
    end
  end

  begin
    diary_data = JSON.parse(File.read(json_path), symbolize_names: true)
  rescue JSON::ParserError
    return { error: "Cache corrupted for #{filename}" }
  end

  if diary_data[:sections].is_a?(Array)
    diary_data[:sections].select! { |section| visible_section?(section, user_ruri) }
  end

  diary_data[:date] = display_date
  diary_data[:week_day] = week_day
  diary_data
end

def find_same_day_diaries(month, day)
  m_str = sprintf("%02d", month)
  d_str = sprintf("%02d", day)
  pattern = File.join(DIARY_ROOT, "**", "d????#{m_str}#{d_str}.hnf")
  Dir.glob(pattern).sort.reverse
end

# --- PIM Parser Logic (Repeat) ---
class PimParser
  WDAYS = %w(日 月 火 水 木 金 土)
  
  # 曜日マッピング (英語, 日本語)
  WDAY_MAP = {
    'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6,
    '日' => 0, '月' => 1, '火' => 2, '水' => 3, '木' => 4, '金' => 5, '土' => 6
  }

  def self.parse_schedule(path, days_window = 40)
    return [] unless File.exist?(path)
    
    events = []
    lines = File.readlines(path, encoding: 'UTF-8').map(&:chomp).reject { |l| l =~ /^#/ || l.strip.empty? }
    
    start_date = Date.today
    end_date = start_date + days_window

    (start_date..end_date).each do |target_date|
      lines.each do |line|
        # 書式: 日付指定[範囲指定] 予定
        if line =~ /^(\S+?)(\[.+?\])?\s+(.+)/
          date_spec = $1
          range_spec = $2
          content = $3
          
          # 範囲チェック
          next if range_spec && !in_range?(target_date, range_spec)
          
          # 日付マッチチェック
          if match_date?(target_date, date_spec)
            formatted_date = "#{target_date.month}/#{target_date.day}(#{WDAYS[target_date.wday]})"
            events << { date: formatted_date, content: content, sort_key: target_date, type: 'repeat' }
          end
        end
      end
    end
    events
  end

  def self.match_date?(date, spec)
    # 1. MM/DD
    if spec =~ /^(\d{1,2})\/(\d{1,2})$/
      return date.month == $1.to_i && date.day == $2.to_i
    end
    # 2. MM/nWDAY (例: 10/2月)
    if spec =~ /^(\d{1,2})\/(-?\d)([a-z]+|[\p{Han}]+)$/i
      month = $1.to_i
      nth = $2.to_i
      wday_str = $3
      return false unless date.month == month
      target_wday = WDAY_MAP[wday_str.downcase]
      return false unless target_wday && date.wday == target_wday
      return is_nth_wday?(date, nth)
    end
    # 3. MM/a, b, c
    if spec =~ /^(\d{1,2})\/([abc])$/i
      month = $1.to_i
      part = $2.downcase
      return false unless date.month == month
      case part
      when 'a' then return date.day <= 10
      when 'b' then return date.day >= 11 && date.day <= 20
      when 'c' then return date.day >= 21
      end
    end
    # 4. 毎月 DD
    if spec =~ /^(\d{1,2})$/
      return date.day == $1.to_i
    end
    # 5. 毎月 末日 (e)
    if spec.downcase == 'e'
      last_day = Date.new(date.year, date.month, -1).day
      return date.day == last_day
    end
    # 6. 毎週 WDAY
    if WDAY_MAP.key?(spec.downcase)
      return date.wday == WDAY_MAP[spec.downcase]
    end
    # 7. 毎月 nWDAY
    if spec =~ /^(-?\d)([a-z]+|[\p{Han}]+)$/i
      nth = $1.to_i
      wday_str = $2
      target_wday = WDAY_MAP[wday_str.downcase]
      return false unless target_wday && date.wday == target_wday
      return is_nth_wday?(date, nth)
    end
    false
  end

  def self.is_nth_wday?(date, nth)
    if nth > 0
      return ((date.day - 1) / 7 + 1) == nth
    else
      last_day = Date.new(date.year, date.month, -1)
      days_left = last_day.day - date.day
      return (days_left / 7 + 1) == nth.abs
    end
  end

  def self.in_range?(date, range_str)
    content = range_str.gsub(/[\[\]]/, '')
    start_s, end_s = content.split('-')
    
    parse_d = ->(s) {
      return nil unless s
      parts = s.split('/').map(&:to_i)
      case parts.size
      when 1 then { y: parts[0] }
      when 2 then { y: parts[0], m: parts[1] }
      when 3 then { y: parts[0], m: parts[1], d: parts[2] }
      else nil end
    }

    s_obj = parse_d.call(start_s)
    e_obj = parse_d.call(end_s)
    
    if s_obj
      return false if date.year < s_obj[:y]
      if date.year == s_obj[:y]
        if s_obj[:m]
          return false if date.month < s_obj[:m]
          if date.month == s_obj[:m] && s_obj[:d]
             return false if date.day < s_obj[:d]
          end
        end
      end
    end

    if e_obj
      return false if date.year > e_obj[:y]
      if date.year == e_obj[:y]
        if e_obj[:m]
          return false if date.month > e_obj[:m]
          if date.month == e_obj[:m] && e_obj[:d]
             return false if date.day > e_obj[:d]
          end
        end
      end
    end

    true
  end

  def self.parse_todo(path)
    return [] unless File.exist?(path)
    File.read(path, encoding: 'UTF-8').lines.map { |line|
      line.chomp!
      next if line =~ /^#/ || line.strip.empty?
      if line =~ /^(\d+)\s+(.*)/
        { priority: $1.to_i, content: $2 }
      else nil end
    }.compact.sort_by { |i| -i[:priority] }
  end

  def self.parse_link(path)
    return [] unless File.exist?(path)
    File.read(path, encoding: 'UTF-8').lines.map { |line|
      line.chomp!
      next if line =~ /^#/ || line.strip.empty?
      parts = line.split(/\s+/, 3)
      if parts.length >= 2
        { priority: parts[0].to_i, url: parts[1], title: parts[2] || parts[1] }
      else nil end
    }.compact.sort_by { |i| -i[:priority] }
  end
end

# --- Monthly Schedule Parser (yYYYYMM) ---
class MonthlyScheduleParser
  # visible_ids: 表示許可されたカレンダー識別子の配列 (nilの場合は全許可)
  def self.load_range(data_root, start_date, end_date, user_ruri, visible_ids = nil)
    schedules = []
    target_years = (start_date.year..end_date.year).to_a.uniq
    calendars_config = CONFIG['calendars'] || {}

    target_years.each do |year|
      pattern = File.join(data_root, year.to_s, "y#{year}*")
      
      Dir.glob(pattern).each do |path|
        filename = File.basename(path)
        
        # カレンダーIDの抽出 (例: y2026_work -> work, y2026 -> nil)
        calendar_id = nil
        if filename =~ /^y\d{4}_(.+)$/
          calendar_id = $1
        end

        # --- 1. 表示可否判定 (Themeによるフィルタ) ---
        is_visible = false
        if calendar_id.nil?
          is_visible = true # 基本ファイルは常に表示
        elsif visible_ids.nil?
          is_visible = true # 制限なしなら全て表示
        elsif visible_ids.include?(calendar_id)
          is_visible = true # 許可リストにあれば表示
        end

        next unless is_visible

        # --- 2. 権限チェック & スタイル取得 ---
        file_style = nil
        if calendar_id && calendars_config[calendar_id]
          conf = calendars_config[calendar_id]
          
          # グループ制限があればチェック
          if conf['group'] && !conf['group'].empty?
            unless AUTH_MANAGER.can_view?(conf['group'], user_ruri)
              next # 権限がないのでスキップ
            end
          end
          
          file_style = conf['style']
        end

        # --- 3. ファイル読み込みと解析 ---
        # エンコーディングエラー回避のためバイナリ読み込み後に変換
        content = File.read(path, mode: 'rb')
        content.force_encoding('UTF-8')

        content.each_line(chomp: true) do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')

          # フォーマット: 月/日[スペース]予定
          # 日付部分: 数字 or a/b/c (旬) or 数字/文字 (除外文字指定で柔軟にマッチ)
          if line =~ /^(\d+)\/([^\s\/]+)\s+(.+)$/
            m_part, d_part, content_str = $1.to_i, $2, $3

            # 日付オブジェクト生成と期間チェックを行うラムダ
            check_date_and_add = ->(d_val, fuzzy_label = nil) {
              begin
                target_d = Date.new(year, m_part, d_val)
                if target_d >= start_date && target_d <= end_date
                  wday = %w(日 月 火 水 木 金 土)[target_d.wday]
                  display = fuzzy_label ? "#{m_part}/#{fuzzy_label}" : "#{m_part}/#{d_val}(#{wday})"
                  
                  schedules << {
                    date: display,
                    content: content_str,
                    sort_key: target_d,
                    type: 'monthly',
                    style: file_style
                  }
                end
              rescue
                # 無効な日付は無視
              end
            }

            # 日付部分の判定 (旬 or 日)
            case d_part.downcase
            when 'a' then check_date_and_add.call(5, '上旬')
            when 'b' then check_date_and_add.call(15, '中旬')
            when 'c' then check_date_and_add.call(25, '下旬')
            else check_date_and_add.call(d_part.to_i, nil)
            end
          end
        end
      end
    end
    schedules
  end
end

class SearchIndexer
  def self.rebuild(db_path, diary_root)
    File.delete(db_path) if File.exist?(db_path)
    db = SQLite3::Database.new(db_path)
    db.execute("CREATE VIRTUAL TABLE entries USING fts5(date, anchor_id, title, content, group_name, tokenize='trigram')")
    
    count = 0
    db.transaction do
      files = Dir.glob(File.join(diary_root, "**", "d*.hnf")).sort
      files.each do |file|
        basename = File.basename(file)
        next unless basename =~ /d(\d{4})(\d{2})(\d{2})\.hnf/
        date_str = "#{$1}/#{$2}/#{$3}"
        begin
          data = HnfParser.parse_file(file)
        rescue; next; end
        if data[:sections]
          data[:sections].each do |section|
            content_text = extract_text(section[:items])
            clean_content = content_text.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
            clean_title = section[:title].to_s.gsub(/<[^>]+>/, ' ').strip
            group_val = section[:group] || ""
            db.execute("INSERT INTO entries (date, anchor_id, title, content, group_name) VALUES (?, ?, ?, ?, ?)", 
              [date_str, section[:anchor_id], clean_title, clean_content, group_val])
            count += 1
          end
        end
      end
    end
    db.close
    count
  end

  def self.update_single_file(db_path, file_path)
    return unless File.exist?(db_path) && File.exist?(file_path)
    basename = File.basename(file_path, ".hnf")
    return unless basename =~ /d(\d{4})(\d{2})(\d{2})/
    date_str = "#{$1}/#{$2}/#{$3}"

    begin
      data = HnfParser.parse_file(file_path)
    rescue
      return
    end

    db = SQLite3::Database.new(db_path)
    db.transaction do
      db.execute("DELETE FROM entries WHERE date = ?", [date_str])
      if data[:sections]
        data[:sections].each do |section|
          content_text = extract_text(section[:items])
          clean_content = content_text.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
          clean_title = section[:title].to_s.gsub(/<[^>]+>/, ' ').strip
          group_val = section[:group] || ""
          db.execute("INSERT INTO entries (date, anchor_id, title, content, group_name) VALUES (?, ?, ?, ?, ?)", 
            [date_str, section[:anchor_id], clean_title, clean_content, group_val])
        end
      end
    end
    db.close
  end

  def self.extract_text(items)
    return "" unless items.is_a?(Array)
    text_buffer = []
    items.each do |item|
      if item.is_a?(String)
        text_buffer << item
      elsif item.is_a?(Hash)
        text_buffer << item[:content] if item[:content]
        text_buffer << item[:alt] if item[:alt]
        text_buffer << extract_text(item[:items]) if item[:items]
        if item[:rows]
          item[:rows].flatten.each { |cell| text_buffer << cell.to_s }
        end
      end
    end
    text_buffer.join(" ")
  end
end

def get_theme_config
  theme_conf = CONFIG['theme']
  if theme_conf.is_a?(Hash)
    # ハッシュ形式の場合 (name, visible_calendars)
    return theme_conf['name'], theme_conf['visible_calendars']
  else
    # 文字列または未設定の場合
    return (theme_conf || 'bootstrap'), nil
  end
end

# --- Routes ---

before do
  ensure_ruri
end

get '/' do
  theme_name, _ = get_theme_config # テーマ名だけ必要
  theme_path = File.join(settings.public_folder, "#{theme_name}.html")
  if File.exist?(theme_path)
    send_file theme_path
  else
    status 404
    content_type :text
    "Error: Theme file '#{theme_name}.html' not found in public directory."
  end
end

post '/api/auth/login' do
  content_type :json
  request.body.rewind
  data = JSON.parse(request.body.read) rescue {}
  input_ruri = data['ruri']
  if input_ruri.nil? || input_ruri.empty?
    status 400
    return { status: 'error', message: 'RURIコードが空です' }.to_json
  end
  if AUTH_MANAGER.known_ruri?(input_ruri)
    response.set_cookie('hns_ruri', {
      value: input_ruri, path: '/', expires: Time.now + (365 * 24 * 60 * 60 * 10), httponly: true
    })
    { status: 'success', message: '認証に成功しました', ruri: input_ruri }.to_json
  else
    status 403
    { status: 'error', message: '無効なRURIコードです' }.to_json
  end
end

post '/api/auth/regenerate' do
  content_type :json
  new_ruri = "RURI" + SecureRandom.alphanumeric(12)
  response.set_cookie('hns_ruri', {
    value: new_ruri, path: '/', expires: Time.now + (365 * 24 * 60 * 60 * 10), httponly: true
  })
  { status: 'success', message: '新しいRURIを発行しました', ruri: new_ruri }.to_json
end

post '/api/entry' do
  content_type :json
  begin
    request.body.rewind
    params = JSON.parse(request.body.read)
    input_ruri = params['ruri']
    input_pass = params['password']
    
    pass_file = File.join(DIARY_ROOT, 'conf', 'admin_pass.txt')
    unless File.exist?(pass_file)
      status 500
      return { status: "error", message: "Password file not found." }.to_json
    end
    real_password = File.read(pass_file).strip
    unless input_pass == real_password
      status 401
      return { status: "error", message: "Invalid Password" }.to_json
    end
    unless valid_ruri?(input_ruri)
      status 401
      return { status: "error", message: "Invalid RURI code" }.to_json
    end

    target_date = params['date'] ? Date.parse(params['date']) : Date.today
    year_str = target_date.year.to_s
    filename = "d#{target_date.strftime('%Y%m%d')}.hnf"
    dir_path = File.join(DIARY_ROOT, year_str)
    FileUtils.mkdir_p(dir_path)
    file_path = File.join(dir_path, filename)

    header = "OK\n"
    header += "CAT #{params['category']}\n" if params['category'] && !params['category'].empty?
    full_content = header + (params['content'] || "")
    
    File.write(file_path, full_content)
    File.chmod(0644, file_path)

    SearchIndexer.update_single_file(DB_PATH, file_path)
    if Dir.exist?(CACHE_ROOT)
      Dir.glob(File.join(CACHE_ROOT, "**", "*.json")).each { |f| File.delete(f) }
    end
    { status: "success", path: file_path }.to_json
  rescue => e
    status 500
    { status: "error", message: e.message }.to_json
  end
end

get '/api/auth/status' do
  content_type :json
  ruri = request.cookies['hns_ruri']
  { is_admin: is_admin?, is_valid: AUTH_MANAGER.known_ruri?(ruri), ruri: ruri }.to_json
end

get '/logout' do
  response.delete_cookie('hns_ruri')
  "<h1>ログアウトしました</h1><a href='/'>トップへ戻る</a>"
end

# PIMデータ取得 (修正: Monthly Schedule Range + Repeat)
get '/api/pim' do
  content_type :json

  start_date = Date.today
  end_date = start_date + 40

  schedule_data = PimParser.parse_schedule(PIM_FILES[:schedule], 40)

  # ★変更: テーマ設定から表示許可リストを取得して渡す
  _, visible_calendars = get_theme_config
  puts "[DEBUG] visible_calendars: #{visible_calendars}"
  
  monthly_data = MonthlyScheduleParser.load_range(
    DIARY_ROOT, 
    start_date, 
    end_date, 
    current_ruri, 
    visible_calendars # 追加引数
  )

  schedule_data += monthly_data
  schedule_data.sort_by! { |item| item[:sort_key] }
  schedule_data.each { |item| item.delete(:sort_key) }

  {
    schedule: schedule_data,
    todo:     PimParser.parse_todo(PIM_FILES[:todo]),
    links:    PimParser.parse_link(PIM_FILES[:link])
  }.to_json
end

get '/api/parts' do
  content_type :json
  head_content = File.exist?(PARTS_FILES[:head]) ? File.read(PARTS_FILES[:head]) : ""
  foot_content = File.exist?(PARTS_FILES[:foot]) ? File.read(PARTS_FILES[:foot]) : ""
  head_content = head_content.encode('UTF-8', 'EUC-JP', invalid: :replace, undef: :replace)
  foot_content = foot_content.encode('UTF-8', 'EUC-JP', invalid: :replace, undef: :replace)
  { head: head_content, foot: foot_content }.to_json
end

get '/api/index/:year/:month/:day' do
  content_type :json
  base_date = Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
  index_data = []
  count = 0
  max_days = 10 
  all_files = Dir.glob(File.join(DIARY_ROOT, "**", "d*.hnf")).sort.reverse
  all_files.each do |f|
    break if count >= max_days
    basename = File.basename(f)
    next unless basename =~ /d(\d{4})(\d{2})(\d{2})\.hnf/
    y, m, d = $1.to_i, $2.to_i, $3.to_i
    file_date = Date.new(y, m, d)
    next if file_date > base_date
    date_id_base = sprintf("%04d%02d%02d", y, m, d)
    titles = []
    current_group = nil
    counter_public = 0
    counter_group = 0
    File.read(f, encoding: 'UTF-8').each_line do |line|
      line.chomp!
      if line =~ /^GRP\s+(.*)/
        g = $1.strip
        current_group = (g.empty? || g.downcase == 'public') ? nil : g
      elsif line =~ /^(NEW|LNEW)\s+(.*)/
        raw_content = $2
        title_text = raw_content
        if $1 == 'LNEW' && raw_content =~ /^\S+\s+(.*)/
          title_text = $1
        end
        if current_group
          counter_group += 1
          anchor_id = "#{date_id_base}g#{counter_group}"
        else
          counter_public += 1
          anchor_id = "#{date_id_base}p#{counter_public}"
        end
        titles << { title: title_text, anchor_id: anchor_id }
      end
    end
    index_data << {
      year: y, month: m, day: d,
      date: sprintf("%04d/%02d/%02d", y, m, d),
      titles: titles
    }
    count += 1
  end
  { index: index_data }.to_json
end

get '/api/search' do
  content_type :json
  query = params[:q].to_s.gsub('　', ' ').strip
  case_sensitive = params[:case_sensitive] == 'true'
  user_ruri = current_ruri
  return { results: [] }.to_json if query.empty?
  unless File.exist?(DB_PATH)
    return { error: "Search database not found.", results: [] }.to_json
  end
  begin
    db = SQLite3::Database.new(DB_PATH)
    db.results_as_hash = true
    sql = <<~SQL
      SELECT 
        date, anchor_id, title, content, group_name,
        snippet(entries, 3, '<span class="search-highlight">', '</span>', '...', 64) as fragment
      FROM entries WHERE entries MATCH ? ORDER BY date DESC LIMIT 100
    SQL
    search_term = query.gsub('"', '""')
    results = []
    db.execute(sql, [search_term]) do |row|
      next unless AUTH_MANAGER.can_view?(row['group_name'], user_ruri)
      if case_sensitive
        next unless (row['title'] && row['title'].include?(query)) || 
                    (row['content'] && row['content'].include?(query))
      end
      results << {
        date: row['date'], anchor_id: row['anchor_id'],
        title: row['title'], fragment: row['fragment']
      }
    end
    { results: results }.to_json
  rescue SQLite3::SQLException => e
    return { error: e.message, results: [] }.to_json
  ensure
    db&.close
  end
end

post '/api/search/rebuild' do
  content_type :json
  unless is_admin?
    halt 403, { status: "error", message: "Forbidden: Administrator privileges required." }.to_json
  end
  begin
    count = SearchIndexer.rebuild(DB_PATH, DIARY_ROOT)
    { status: "success", count: count }.to_json
  rescue => e
    status 500
    { status: "error", message: e.message }.to_json
  end
end

get '/api/feed/:year/:month' do
  content_type :json
  user_ruri = current_ruri
  y = params[:year]
  m = sprintf("%02d", params[:month].to_i)
  pattern = File.join(DIARY_ROOT, y, "d#{y}#{m}*.hnf")
  files = Dir.glob(pattern).sort
  diaries = files.map { |f| process_diary_file(f, user_ruri) }.compact
  {
    meta: { request_date: "#{y}/#{m}", count: diaries.size, mode: 'monthly', viewer_ruri: user_ruri },
    diaries: diaries
  }.to_json
end

get '/api/feed/:year/:month/:day' do
  content_type :json
  user_ruri = current_ruri
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  limit = params[:limit] ? params[:limit].to_i : DAYS_SHOWN
  files = find_diary_files(year, month, day, limit)
  if files.empty?
    status 404
    return { error: "No diary entries found starting from #{year}/#{month}/#{day}" }.to_json
  end
  diaries = files.map { |f| process_diary_file(f, user_ruri) }.compact
  {
    meta: { request_date: "#{year}/#{month}/#{day}", days_shown: limit, count: diaries.size, viewer_ruri: user_ruri },
    diaries: diaries
  }.to_json
end

get '/api/calendar_monthly/:year/:month' do
  content_type :json
  year = params[:year].to_i
  month = params[:month].to_i
  month_str = sprintf("%02d", month)
  pattern = File.join(DIARY_ROOT, year.to_s, "d#{year}#{month_str}*.hnf")
  existing_days = Dir.glob(pattern).map { |f|
    basename = File.basename(f)
    if basename =~ /d\d{6}(\d{2})\.hnf/
      $1.to_i
    else nil end
  }.compact.uniq.sort
  { year: year, month: month, days: existing_days }.to_json
end

get '/api/same_day/:month/:day' do
  content_type :json
  user_ruri = current_ruri
  month = params[:month].to_i
  day = params[:day].to_i
  files = find_same_day_diaries(month, day)
  if files.empty?
    status 404
    return { error: "No entries found for #{month}/#{day}" }.to_json
  end
  diaries = files.map { |f| process_diary_file(f, user_ruri) }.compact
  {
    meta: { request_date: "#{month}/#{day}", count: diaries.size, mode: 'same_day', viewer_ruri: user_ruri },
    diaries: diaries
  }.to_json
end

get '/api/years' do
  content_type :json
  years = Dir.glob(File.join(DIARY_ROOT, "[0-9][0-9][0-9][0-9]"))
             .map { |path| File.basename(path).to_i }
             .uniq.sort.reverse
  { years: years }.to_json
end

get '/api/category' do
  content_type :json
  target_cat = params[:q]
  if target_cat.nil? || target_cat.empty?
    return { category: "", results: [] }.to_json
  end
  results = []
  files = Dir.glob(File.join(DIARY_ROOT, "**", "d*.hnf")).sort.reverse
  files.each do |f|
    next unless File.basename(f) =~ /d(\d{4})(\d{2})(\d{2})\.hnf/
    date_str = "#{$1}/#{$2}/#{$3}"
    current_cat = nil
    File.read(f, encoding: 'UTF-8').each_line do |line|
      line.chomp!
      if line =~ /^CAT\s+(.*)/
        current_cat = $1.strip
      elsif line =~ /^(NEW|LNEW)\s+(.*)/
        type = $1
        content = $2
        if current_cat
          cats = current_cat.split(/\s+/)
          if cats.include?(target_cat)
            title = content
            url = nil
            if type == 'LNEW' && content =~ /^(\S+)\s+(.*)/
               url = $1
               title = $2
            end
            results << { date: date_str, title: title, url: url }
          end
        end
      end
    end
  end
  { category: target_cat, results: results }.to_json
end

get '/api/config' do
  content_type :json
  { days_shown: DAYS_SHOWN }.to_json
end

delete '/api/cache/all' do
  content_type :json
  unless is_admin?
    halt 403, { status: "error", message: "Forbidden: Administrator privileges required." }.to_json
  end
  count = 0
  Dir.glob(File.join(CACHE_ROOT, "**", "*.json")).each do |file|
    File.delete(file)
    count += 1
  end
  { status: "deleted", count: count, cache_dir: CACHE_ROOT }.to_json
end
