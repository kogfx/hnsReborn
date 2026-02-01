# hnsReborn - Hyper Nikki System Reborn
# Copyright (c) 2026 kogfx (@kogfx)
# Released under the MIT License.

class AuthManager
  def initialize(diary_root)
    @diary_root = diary_root
    @groups = {}
    load_groups
  end

  def load_groups
    group_file = File.join(@diary_root, 'conf', 'group.txt')
    @groups = {}
    return unless File.exist?(group_file)

    File.foreach(group_file) do |line|
      line.chomp!
      line.sub!(/#.*/, '')
      next if line.strip.empty?
      parts = line.strip.split(/\s+/)
      next if parts.empty?
      group_name = parts.shift
      @groups[group_name] = parts # RURI list
    end
  end

  def can_view?(group_name, user_ruri)
    return true if group_name.nil? || group_name.empty? || group_name.downcase == 'public'
    load_groups
    allowed_ruris = @groups[group_name]
    return false unless allowed_ruris
    return false if user_ruri.nil? || user_ruri.empty?
    allowed_ruris.include?(user_ruri)
  end

  # ★追加: そのRURIコードはシステムにとって「既知」か？
  # (管理者リスト または グループリスト に含まれているか)
  def known_ruri?(ruri)
    return false if ruri.nil? || ruri.empty?

    # 1. 管理者チェック (auth_ruri.txt)
    auth_file = File.join(@diary_root, 'conf', 'auth_ruri.txt')
    if File.exist?(auth_file)
      admins = File.readlines(auth_file).map(&:strip)
      return true if admins.include?(ruri)
    end

    # 2. グループユーザーチェック (group.txt)
    load_groups
    @groups.each_value do |ruri_list|
      return true if ruri_list.include?(ruri)
    end

    false
  end
end
