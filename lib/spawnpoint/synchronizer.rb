# frozen_string_literal: true

# Synchronizer implements `spwn sync`.
#
# It copies a lesson source folder into a DragonRuby game folder (usually
# mygame/). It is intentionally a copy tool, not a Git command: the course
# materials are distributed as folders, and the student's game folder is the
# place where DragonRuby loads them.
#
# Design notes:
#
# - Source is a directory, not a single file. Lessons are more than one file
#   once assets enter the picture.
# - Existing files are never overwritten without the student saying so. This
#   matters most for assets: a later lesson may ship a better sprite, and the
#   student should choose whether to replace the older one.
# - When the source contains an assets/ folder, the sync prints a reminder that
#   assets are part of this lesson and may change between lessons.

require "fileutils"
require "pathname"
require "set"

module Spawnpoint
  class Synchronizer
    BACKUP_DIR = ".spwn_sync_backup"

    def run(argv)
      lesson_folder, into_folder, force = parse_args(argv)

      unless lesson_folder
        puts "Usage:"
        puts "  spwn sync <lesson-folder> --into <game-folder>"
        puts "  spwn sync <lesson-folder> --into <game-folder> --force"
        puts ""
        puts "Example:"
        puts "  spwn sync 04-collectibles/starter --into ~/DragonRuby/mygame"
        puts ""
        puts "The first time a lesson copies a file that already exists in your"
        puts "game folder, spwn asks before replacing it. After you accept a"
        puts "file, later lessons replace that same file automatically."
        return 1
      end

      unless into_folder
        puts "Oops: tell spwn where to copy the lesson with --into."
        puts "Example: spwn sync 04-collectibles/starter --into ~/DragonRuby/mygame"
        return 1
      end

      source = Pathname.new(lesson_folder).expand_path
      target = Pathname.new(into_folder).expand_path

      unless source.directory?
        puts "Oops: #{source} is not a folder."
        return 1
      end

      unless target.directory?
        puts "Oops: #{target} is not a folder yet."
        return 1
      end

      has_assets = source.join("assets").directory?

      if has_assets
        puts "This lesson includes an assets/ folder."
        puts "Assets may look different from the previous lesson. "
        puts "If you already have sprites from an older lesson, you will be asked before each one is replaced."
        puts ""
      end

      marker = target.join(".spwn_synced_paths")
      backup = target.join(BACKUP_DIR)
      FileUtils.rm_rf(backup)
      backup.join("files").mkpath
      backup.join("created_paths").write("")
      if marker.file?
        FileUtils.cp(marker, backup.join("marker"))
      else
        backup.join("no_marker").write("")
      end

      known = if marker.file?
        marker.readlines.map(&:strip).reject(&:empty?).to_set
      else
        Set.new
      end

      already_existed = Set.new
      target.find.each do |child|
        next unless child.file?
        already_existed << child.relative_path_from(target).to_s
      end

      copied = 0
      upgraded = 0
      skipped = 0
      new_known = Set.new

      source.find.to_a.each do |child|
        next unless child.file?

        rel = child.relative_path_from(source)
        rel_s = rel.to_s
        dest = target.join(rel)

        if dest.exist?
          if force || known.include?(rel_s)
            backup_existing(backup, dest, rel_s)
            copy_file(child, dest)
            upgraded += 1
            new_known << rel_s
          elsif already_existed.include?(rel_s)
            if agree?("Copy #{rel} from this lesson?")
              backup_existing(backup, dest, rel_s)
              copy_file(child, dest)
              upgraded += 1
              new_known << rel_s
            else
              skipped += 1
            end
          end
        else
          copy_file(child, dest)
          File.open(backup.join("created_paths"), "a") { |fh| fh.puts(rel_s) }
          copied += 1
          new_known << rel_s
        end
      end

      merged = known | new_known
      if merged.any?
        marker.open("w") do |fh|
          merged.to_a.sort.each do |name|
            fh.puts(name)
          end
        end
      end

      puts ""
      puts "Done."
      puts "New:       #{copied}"
      puts "Updated:   #{upgraded}"
      puts "Skipped:   #{skipped}"

      0
    end

    def rollback(argv)
      target = parse_rollback_args(argv)
      unless target
        puts "Usage: spwn rollback --into <game-folder>"
        return 1
      end

      target = Pathname.new(target).expand_path
      backup = target.join(BACKUP_DIR)
      unless backup.directory?
        puts "Oops: there is no lesson sync to roll back in #{target}."
        return 1
      end

      backup.join("created_paths").readlines.each do |line|
        target.join(line.strip).delete if !line.strip.empty? && target.join(line.strip).file?
      end
      backup.join("files").find do |saved|
        next if saved.directory? || saved == backup.join("files")
        rel = saved.relative_path_from(backup.join("files"))
        dest = target.join(rel)
        FileUtils.mkdir_p(dest.parent)
        FileUtils.cp(saved, dest)
      end

      marker = target.join(".spwn_synced_paths")
      if backup.join("marker").file?
        FileUtils.cp(backup.join("marker"), marker)
      else
        marker.delete if marker.file?
      end

      FileUtils.rm_rf(backup)
      puts "Rolled back the most recent lesson sync."
      0
    end

    private

    def parse_args(argv)
      lesson_folder = nil
      into_folder = nil
      force = false

      i = 0
      while i < argv.length
        arg = argv[i]
        case arg
        when "--into"
          i += 1
          into_folder = argv[i]
        when "--force", "-f"
          force = true
        when /\A-/
          puts "Oops: I do not understand #{arg}."
          return [nil, nil, false]
        else
          lesson_folder ||= arg
        end
        i += 1
      end

      [lesson_folder, into_folder, force]
    end

    def parse_rollback_args(argv)
      i = argv.index("--into")
      i && argv[i + 1]
    end

    def backup_existing(backup, dest, rel)
      saved = backup.join("files", rel)
      FileUtils.mkdir_p(saved.parent)
      FileUtils.cp(dest, saved)
    end

    def copy_file(source, dest)
      FileUtils.mkdir_p(dest.parent)
      FileUtils.cp(source, dest)
    end

    def agree?(question)
      loop do
        print "#{question} (y/n): "
        answer = STDIN.gets
        return false if answer.nil?

        answer = answer.strip.downcase
        return true if answer == "y"
        return false if answer == "n"
        puts "Please type y or n."
      end
    end
  end
end
