#! /usr/bin/env ruby
# hnsReborn - Hyper Nikki System Reborn
# Copyright (c) 2026 kogfx (@kogfx)
# Released under the MIT License.

require 'net/http'
require 'icalendar'
require 'date'
require 'fileutils'
require 'yaml'
require 'erb'

# --- 設定読み込み ---
config_file = File.join(File.expand_path(__dir__), 'config.yml')
unless File.exist?(config_file)
  abort "Error: config.yml not found."
end

config = YAML.load(ERB.new(File.read(config_file)).result)
DIARY_ROOT = config['diary_root'] || "./data"
calendars_config = config['calendars']

if calendars_config.nil? || calendars_config.empty?
  abort "Error: 'calendars' not defined in config.yml."
end

# --- メイン処理 ---
calendars_config.each do |source_name, data|
  url = data['url']
  
  if url.nil? || url.empty?
    puts "Skipping [#{source_name}]: URL not defined."
    next
  end

  puts "Fetching calendar: [#{source_name}]..."
  
  begin
    uri = URI(url)
    res = Net::HTTP.get(uri)
    
    if res.nil? || res.strip.empty? || res.include?("<!DOCTYPE html>")
      puts "  Error: Invalid response from URL."
      next
    end

    cals = Icalendar::Calendar.parse(res)
    calendar = cals.first

    schedules_by_year = Hash.new { |h, k| h[k] = [] }

    calendar.events.each do |event|
      start_dt = event.dtstart
      next unless start_dt

      if start_dt.is_a?(Icalendar::Values::Date) || start_dt.is_a?(Date)
        d = start_dt
        time_str = ""
      else
        d = start_dt.to_date
        time_str = start_dt.strftime("%H:%M ")
      end

      summary = event.summary.to_s.strip
      line = "#{d.month}/#{d.day} #{time_str}#{summary}"
      schedules_by_year[d.year] << [start_dt, line]
    end

    schedules_by_year.each do |year, events|
      events.sort_by! { |item| item[0] }
      dir = File.join(DIARY_ROOT, year.to_s)
      FileUtils.mkdir_p(dir)
      
      # ファイル名は従来通り "yYYYY_識別名"
      path = File.join(dir, "y#{year}_#{source_name}")

      puts "  Writing #{events.size} events to #{path}..."
      File.open(path, 'w') do |f|
        f.puts "# Calendar Sync: #{source_name} (Generated at #{Time.now})"
        events.each do |item|
          f.puts item[1]
        end
      end
    end

  rescue => e
    puts "  Error processing [#{source_name}]: #{e.message}"
  end
end

puts "All done!"
