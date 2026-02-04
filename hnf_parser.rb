# hnsReborn - Hyper Nikki System Reborn
# Copyright (c) 2026 kogfx (@kogfx)
# Released under the MIT License.
require 'json'
require 'strscan'

class HnfParser
  # HNFファイルをパースしてHashを返す
  def self.parse_file(file_path)
    return {} unless File.exist?(file_path)
    content = File.read(file_path, encoding: 'UTF-8')
    
    basename = File.basename(file_path, ".*")
    base_id = basename.sub(/^d/, '')

    parse(content, base_id)
  end

  def self.parse(text, base_id = nil)
    base_id ||= Time.now.strftime("%Y%m%d")
    parser = new(text, base_id)
    parser.execute
  end

  def initialize(text, base_id)
    @lines = text.lines.map(&:chomp)
    @base_id = base_id
    
    @meta = {}
    @sections = []
    @current_section = nil
    @current_cat = nil
    @current_group = nil 

    @counter_public = 0
    @counter_group  = 0
    @counter_sub    = 0

    @buffer = []
    @stack = []
    
    @block_mode = nil
    @block_buffer = []
    
    # 直前のアイテムモード (:li, :dt, :dd)
    @last_item_mode = nil
  end

  def execute
    in_header = true

    @lines.each do |line|
      if in_header
        if line == 'OK'
          in_header = false
          next
        end
        if line =~ /^([A-Z]+)\s+(.*)/
          @meta[$1] = $2
        end
        next
      end
      process_line(line)
    end

    flush_buffer
    @sections << @current_section if @current_section

    {
      meta: @meta,
      sections: @sections
    }
  end

  private

  def process_line(line)
    # ブロックモード処理 (PRE, RT, BLOCK)
    if @block_mode
      should_close = false
      case @block_mode
      when :pre
        should_close = true if line =~ /^\/PRE$/
      when :rt
        should_close = true if line =~ /^\/RT$/
      when :block
        should_close = true if line =~ /^\/BLOCK$/
      end

      if should_close
        close_simple_block
      else
        @block_buffer << line
      end
      return
    end

    # --- コマンド判定 (すべて行頭 ^ でマッチ) ---
    case line
    
    # --- 構造・メタデータ系 ---
    when /^CAT\s+(.*)/
      reset_mode
      @current_cat = $1
      
    when /^GRP\s+(.*)/
      reset_mode
      @current_group = $1.strip
      @current_group = nil if @current_group.empty? || @current_group.downcase == 'public'
      
    when /^NEW\s+(.*)/
      reset_mode
      title = process_inline_tags($1)
      start_new_section(title, nil, 'section')
      
    when /^LNEW\s+(\S+)\s+(.*)/
      reset_mode
      title = process_inline_tags($2)
      start_new_section(title, $1, 'link_section')

    when /^SUB\s+(.*)/
      reset_mode
      flush_buffer
      @counter_sub += 1
      sub_id = "#{@current_section[:anchor_id]}S#{@counter_sub}"
      add_item({ type: 'sub_header', title: process_inline_tags($1), anchor_id: sub_id })
      
    when /^LSUB\s+(\S+)\s+(.*)/
      reset_mode
      flush_buffer
      @counter_sub += 1
      sub_id = "#{@current_section[:anchor_id]}S#{@counter_sub}"
      add_item({ type: 'link_sub_header', title: process_inline_tags($2), url: $1, anchor_id: sub_id })

    # --- リスト系 (UL, OL, LI, DL, DT, DD) ---
    when /^(UL|OL)/
      reset_mode
      flush_buffer
      type = $1.downcase
      new_list = { type: type, items: [] }
      add_item(new_list)
      @stack.push(new_list[:items])

    when /^(\/UL|\/OL)/
      reset_mode
      flush_buffer
      @stack.pop if @stack.size > 1

    when /^LI(\s+(.*))?$/
      reset_mode
      flush_buffer
      content = $2 ? process_inline_tags($2.strip) : ""
      if @stack.last
        @stack.last << content
      else
        @buffer << content
      end
      @last_item_mode = :li

    when /^DL/
      reset_mode
      flush_buffer

    when /^\/DL/
      reset_mode
      flush_buffer

    when /^DT(\s+(.*))?$/
      reset_mode
      flush_buffer
      content = $2 ? process_inline_tags($2.strip) : ""
      add_item({ type: 'dt', content: content })
      @last_item_mode = :dt

    when /^DD(\s+(.*))?$/
      reset_mode
      flush_buffer
      content = $2 ? process_inline_tags($2.strip) : ""
      add_item({ type: 'dd', content: content })
      @last_item_mode = :dd

    # --- ブロック要素開始 ---
    when /^RT/
      reset_mode
      start_simple_block(:rt)
    when /^PRE/
      reset_mode
      start_simple_block(:pre)
    when /^BLOCK/
      reset_mode
      start_simple_block(:block)

    # --- HTML要素系 ---
    when /^DIV\s+(\S+)/
      reset_mode
      flush_buffer
      add_item({ type: 'raw', content: "<div class=\"#{$1}\">" })

    when /^\/DIV$/
      reset_mode
      flush_buffer
      add_item({ type: 'raw', content: "</div>" })

    when /^P$/
      reset_mode
      flush_buffer
      add_item({ type: 'raw', content: "<p>" })
    
    when /^\/P$/
      reset_mode
      flush_buffer
      add_item({ type: 'raw', content: "</p>" })

    # --- 修飾・リンク・画像コマンド (行頭必須) ---

    when /^LINK\s+(\S+)\s+(.*)/
      url = $1
      text = process_inline_tags($2)
      handle_text_content(%Q(<a href="#{url}" target="_blank">#{text}</a>))

    when /^URL\s+(\S+)\s+(.*)/
      url = $1
      text = process_inline_tags($2)
      handle_text_content(%Q(<a href="#{url}" target="_blank">#{text}</a>))

    when /^IMG\s+(\S+)\s+(\S+)(?:\s+(.*))?/
      reset_mode
      align_char, src, alt = $1, $2, $3 || ''
      style = case align_char.downcase
              when 'l' then "float: left; margin-right: 1em; margin-bottom: 0.5em;"
              when 'r' then "float: right; margin-left: 1em; margin-bottom: 0.5em;"
              else ""
              end
      flush_buffer
      add_item({ type: 'image', src: src, alt: alt, style: style })

    when /^LIMG\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(.*))?/
      link_url, align_char, src, alt = $1, $2, $3, $4 || ''
      style = case align_char.downcase
              when 'l' then "float: left; margin-right: 1em; margin-bottom: 0.5em;"
              when 'r' then "float: right; margin-left: 1em; margin-bottom: 0.5em;"
              else ""
              end
      flush_buffer
      html = %Q(<a href="#{link_url}" target="_blank"><img src="#{src}" alt="#{alt}" style="#{style}"></a>)
      add_item({ type: 'text', content: html })

    when /^STRONG\s+(.*)/
      content = process_inline_tags($1)
      handle_text_content("<strong>#{content}</strong>")

    when /^STRIKE\s+(.*)/
      content = process_inline_tags($1)
      handle_text_content("<span style=\"text-decoration: line-through;\">#{content}</span>")

    when /^LSTRIKE\s+(\S+)\s+(.*)/
      url = $1
      content = process_inline_tags($2)
      handle_text_content(%Q(<a href="#{url}" target="_blank"><span style="text-decoration: line-through;">#{content}</span></a>))

    when /^FONT\s+(\S+)\s+(\S+)\s+(.*)/
      attr_type = $1.upcase
      attr_val  = $2
      content   = process_inline_tags($3)
      style = (attr_type == 'COLOR') ? "color: #{attr_val};" : "font-size: #{attr_val};"
      handle_text_content("<span style=\"#{style}\">#{content}</span>")

    when /^SPAN\s+(\S+)\s+(.*)/
      cls = $1
      content = process_inline_tags($2)
      handle_text_content("<span class=\"#{cls}\">#{content}</span>")
    
    when /^CITE$/
      reset_mode
      start_simple_block(:block)

    when /^\/CITE$/
      # handled by block close logic if needed

    when /^MARK\s+(.*)/
      mark_text = resolve_mark($1)
      handle_text_content(mark_text)

    when /^ALIAS\s+(.*)/
      handle_text_content("[ALIAS:#{$1}]")

    # ★修正: ! と !# の分岐処理
    when /^!#(.*)/
      # !# は完全無視 (HTMLソースにも出さない)
      return

    when /^!(.*)/
      # ! はHTMLコメントとして出力 ()
      # リスト等の継続を一旦切るために reset_mode する
      reset_mode
      flush_buffer
      content = $1.strip
      # process_inline_tags は通さず、そのままコメントにする
      add_item({ type: 'raw', content: "" })

    else
      if line.strip.empty?
        flush_buffer unless @last_item_mode
      else
        content = process_inline_tags(line)
        handle_text_content(content)
      end
    end
  end

  # --- ヘルパーメソッド ---

  def reset_mode
    @last_item_mode = nil
  end

  def handle_text_content(content)
    if @last_item_mode && @stack.last
      last_item = @stack.last.last
      case @last_item_mode
      when :li
        if last_item.is_a?(String)
          if last_item.empty?
            @stack.last[-1] = content
          else
            @stack.last[-1] += "\n" + content
          end
        end
      when :dt, :dd
        if last_item.is_a?(Hash) && last_item[:content]
          if last_item[:content].empty?
            last_item[:content] = content
          else
            last_item[:content] += "\n" + content
          end
        end
      end
    else
      @buffer << content
    end
  end

  def start_new_section(title, url, type)
    flush_buffer
    @sections << @current_section if @current_section

    if @current_group
      @counter_group += 1
      anchor_id = "#{@base_id}g#{@counter_group}"
    else
      @counter_public += 1
      anchor_id = "#{@base_id}p#{@counter_public}"
    end
    @counter_sub = 0

    @current_section = {
      type: type,
      category: @current_cat,
      group: @current_group,
      title: title,
      url: url,
      items: [],
      visibility: @current_group ? 'restricted' : 'public',
      anchor_id: anchor_id
    }
    
    @current_group = nil 
    @current_cat = nil

    @stack = [@current_section[:items]]
    reset_mode
  end

  def add_item(item)
    return unless @stack.last
    @stack.last << item
  end

  def flush_buffer
    return if @buffer.empty?
    return unless @stack.last

    content = @buffer.join("\n")
    unless content.strip.empty?
      @stack.last << { type: 'text', content: content }
    end
    @buffer = []
  end

  def start_simple_block(type)
    flush_buffer
    @block_mode = type
    @block_buffer = []
  end

  def close_simple_block
    return unless @block_mode
    item = nil
    case @block_mode
    when :pre
      item = { type: 'pre', content: @block_buffer.join("\n") }
    when :block
      item = { type: 'blockquote', content: @block_buffer.join("\n") }
    when :rt
      rows = []
      config = { 'delimiter' => ',' } # デフォルトのデリミタ
      
      @block_buffer.each do |l|
        # 行頭(または空白後)の # はコメント
        if l =~ /^\s*#/
          comment_content = l.sub(/^\s*#/, '').strip
          rows << [""]
          next
        end

        # コマンド (例: caption = タイトル)
        # 拡張された正規表現で全てのRTコマンドに対応
        if l =~ /^\s*([a-zA-Z0-9_]+)\s*=\s*(.*)/
          key, val = $1.downcase, $2.strip
          config[key] = val
          next # コンフィグ行はテーブルの行として追加しない
        end

        # データ行
        # デリミタで分割。空行は空配列として追加し、フロントエンドでヘッダ区切りとして利用
        if l.strip.empty?
          rows << []
        else
          rows << l.split(config['delimiter']).map(&:strip)
        end
      end
      
      item = { 
        type: 'table', 
        caption: config['caption'], 
        config: config,  # 全ての設定を config として渡す
        rows: rows 
      }
    end
    add_item(item) if item
    @block_mode = nil
    @block_buffer = []
  end

  def process_inline_tags(text)
    return "" if text.nil?
    text.gsub!(/~\s*$/, '<br>')
    text.gsub!(/\[\[(\S+?)\s+(.+?)\]\]/, '<a href="\1" target="_blank">\2</a>')
    text
  end

  def resolve_mark(mark_type)
    marks = {
      '(^^)' => '😊', '(-_-)' => '😑', '(^^;' => '😅',
      '(;_;)' => '😢', '(T_T)' => '😭', 'v(^^)' => '✌️',
      'm(__)m' => '🙇', '!!' => '❗', '??' => '❓',
      '!?' => '⁉️', '(笑)' => '(笑)', ':-)' => '🙂',
      ':-(' => '🙁', ':-P' => 'XP', 'φ(._.)' => '📝'
    }
    marks[mark_type] || mark_type
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby hnf_parser.rb <filename.hnf>"
    exit 1
  end
  file_path = ARGV[0]
  unless File.exist?(file_path)
    puts "Error: File not found - #{file_path}"
    exit 1
  end
  begin
    result = HnfParser.parse_file(file_path)
    puts JSON.pretty_generate(result)
  rescue => e
    puts "Error during parsing: #{e.message}"
    puts e.backtrace
  end
end
