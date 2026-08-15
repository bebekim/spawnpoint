# frozen_string_literal: true

require_relative "version"

module Spawnpoint
  # CLI implements the spwn command-line interface.
  #
  # It is a thin wrapper around Git. It renames Git commands into friendlier,
  # game-like language and delegates the actual work to Git.
  #
  # The mapping from "spwn commands" to Git invocations lives in the
  # COMMANDS table below so it is easy to extend without changing the
  # dispatch logic.
  module CLI
    extend self

    # ---------------------------------------------------------------------
    # Helper methods
    # ---------------------------------------------------------------------

    def git(*args)
      system("git", *args)
    end

    def say(message)
      puts message
    end

    def error(message)
      say("Oops: #{message}")
    end

    def ask_yes_no(question)
      loop do
        print "#{question} (y/n): "
        answer = STDIN.gets.to_s.strip.downcase
        return true if answer == "y"
        return false if answer == "n"
        say("Please type y or n.")
      end
    end

    def extract_message_from_args(args)
      message_parts = []
      remaining = []
      i = 0
      while i < args.length
        if args[i] == "-m" && i + 1 < args.length
          message_parts << args[i + 1]
          i += 2
        elsif args[i] == "--message" && i + 1 < args.length
          message_parts << args[i + 1]
          i += 2
        else
          remaining << args[i]
          i += 1
        end
      end
      [message_parts.join(" "), remaining]
    end

    def files_from_args(args, allow_all: false)
      if allow_all && args.include?("-A")
        ["-A"]
      elsif args.empty? || args.include?(".")
        ["."]
      else
        args
      end
    end

    def command_args_include_help?(args)
      args.include?("--help") || args.include?("-h")
    end

    def git_command_exists?(name)
      # A quick probe using git's own error reporting.
      system("git", name, "--help", out: "/dev/null", err: "/dev/null")
    end

    def file_on_head?(path)
      # Returns true when the given path is tracked and present on the current HEAD.
      # We use git ls-files so the check respects the index/HEAD rather than the
      # working tree alone.
      system("git", "ls-files", "--error-unmatch", path, out: "/dev/null", err: "/dev/null")
    end

    # ---------------------------------------------------------------------
    # Command mapping table
    #
    # Each entry is a hash with:
    #   :name        - the spwn subcommand students type
    #   :help        - a short child-friendly description
    #   :usage       - a short usage hint
    #   :handler     - a callable that receives the remaining arguments
    #
    # Keeping this table in one place is deliberate: it is the single place
    # to look when you want to add or change a command.
    # ---------------------------------------------------------------------

    COMMANDS = {
      init: {
        name: "init",
        help: "Start a new project folder that Git can track.",
        usage: "spwn init",
        handler: ->(args) { git("init", *args) }
      },

      save: {
        name: "save",
        help: "Take a snapshot of your work. First pick which files to include, then give your snapshot a note.",
        usage: "spwn save <files...> -m 'your note'   or   spwn save -m 'your note'",
        handler: ->(args) {
          message, _rest = extract_message_from_args(args)
          if message.nil? || message.empty?
            error("Tell spwn what you changed with -m, like: spwn save -m 'added a score'")
            next nil
          end

          if ask_yes_no("Save all the changed files in this folder?")
            git("add", ".")
            git("commit", "-m", message)
          else
            say("Save cancelled. You can pick files one by one with spwn add.")
            1
          end
        }
      },

      add: {
        name: "add",
        help: "Tell Git which files to include in the next snapshot.",
        usage: "spwn add <file>...   or   spwn add .   or   spwn add -A",
        handler: ->(args) {
          files = files_from_args(args, allow_all: true)
          git("add", *files)
        }
      },

      commit: {
        name: "commit",
        help: "Save the files you have already picked. You must include a note with -m.",
        usage: "spwn commit -m 'your note'",
        handler: ->(args) {
          message, _rest = extract_message_from_args(args)
          if message.nil? || message.empty?
            error("Every save needs a note. Try: spwn commit -m 'made the hero jump'")
            next nil
          end
          git("commit", "-m", message)
        }
      },

      look: {
        name: "look",
        help: "See what is going on in your project right now.",
        usage: "spwn look",
        handler: ->(args) { git("status", *args) }
      },

      compare: {
        name: "compare",
        help: "See what changed since the last snapshot.",
        usage: "spwn compare   or   spwn compare <file>",
        handler: ->(args) { git("diff", *args) }
      },

      history: {
        name: "history",
        help: "Replay the story of your project, one snapshot at a time.",
        usage: "spwn history   or   spwn history -n 5",
        handler: ->(args) { git("log", *args) }
      },

      hop: {
        name: "hop",
        help: "Jump to another universe (branch) or bring back a file from another snapshot.",
        usage: "spwn hop <branch>   or   spwn hop -- <branch> <file>",
        handler: ->(args) {
          if args.empty?
            error("Where should we hop? Try a branch name, or use spwn hop -- <branch> <file> to restore a file.")
            next nil
          end

          if args[0] == "--"
            rest = args[1..]
            if rest.nil? || rest.empty?
              error("What should we restore? Try: spwn hop -- main my_level.rb")
              next nil
            end

            if rest.length == 1
              # Only one thing after --: could be a branch or a file.
              # If it is a file that exists on the current HEAD, restore it from here.
              # Otherwise ask for the source branch explicitly.
              candidate = rest[0]
              if file_on_head?(candidate)
                next git("restore", "--", candidate)
              else
                error("I cannot tell which universe to pull #{candidate} from. Try: spwn hop -- <branch> #{candidate}")
                next nil
              end
            else
              # branch followed by one or more files
              source_branch = rest[0]
              files = rest[1..]
              if files.nil? || files.empty?
                error("Which file should we bring back from #{source_branch}? Try: spwn hop -- #{source_branch} my_level.rb")
                next nil
              end
              next git("restore", "--source", source_branch, "--", *files)
            end
          end

          git("switch", *args)
        }
      },

      upload: {
        name: "upload",
        help: "Send your snapshots to the shared project space.",
        usage: "spwn upload   or   spwn upload <branch>",
        handler: ->(args) { git("push", *args) }
      },

      download: {
        name: "download",
        help: "Fetch new snapshots from the shared project space and combine them with yours.",
        usage: "spwn download   or   spwn download <remote> <branch>",
        handler: ->(args) { git("pull", *args) }
      },

      sync: {
        name: "sync",
        help: "Copy a lesson folder into your game folder. The first time a lesson touches a file that already exists in your game folder, spwn asks before replacing it. After you accept a file, later lessons upgrade that same file automatically, so asset updates get easier as you go.",
        usage: "spwn sync <lesson-folder> --into <game-folder>   or   spwn sync <lesson-folder> --into <game-folder> --force",
        handler: ->(args) { require_relative "synchronizer"; Spawnpoint::Synchronizer.new.run(args) }
      },

      rollback: {
        name: "rollback",
        help: "Undo the most recent lesson sync.",
        usage: "spwn rollback --into <game-folder>",
        handler: ->(args) { require_relative "synchronizer"; Spawnpoint::Synchronizer.new.rollback(args) }
      }
    }.freeze

    SUBCOMMANDS = COMMANDS.values.freeze

    # ---------------------------------------------------------------------
    # Help text
    # ---------------------------------------------------------------------

    def print_help
      say("spwn v#{VERSION}")
      say("A friendly face for Git, made for learning game programming.")
      say("")
      say("Usage:")
      say("  spwn <command> [options]")
      say("")
      say("Commands:")
      SUBCOMMANDS.sort_by { |c| c[:name] }.each do |cmd|
        say("  #{cmd[:name].to_s.ljust(12)} #{cmd[:help]}")
      end
      say("")
      say("Tips:")
      say("  - Run spwn <command> --help to see Git's own help for that command.")
      say("  - You can still use git directly when you are ready.")
      say("  - spwn save is a shortcut for adding changed files and committing them together.")
    end

    def print_command_help(command_name)
      cmd = COMMANDS[command_name]
      if cmd.nil?
        error("I do not know that command. Run spwn --help to see the list.")
        return
      end

      say("spwn #{cmd[:name]}")
      say("")
      say(cmd[:help])
      say("")
      say("Usage:")
      say("  #{cmd[:usage]}")
    end

    # ---------------------------------------------------------------------
    # Dispatch
    # ---------------------------------------------------------------------

    # Runs the CLI and returns an Integer exit code.
    #
    # Handlers return an Integer exit code, or true/false from `system`.
    # Anything truthy-but-not-an-Integer and `true` map to 0; false and nil
    # map to 1, so misuse and Git failures exit non-zero.
    def run(argv)
      command_name = argv[0]

      if command_name.nil? || command_name == "--help" || command_name == "-h"
        print_help
        return 0
      end

      if command_name == "--version" || command_name == "-v"
        say("spwn v#{VERSION}")
        return 0
      end

      command_key = command_name.to_sym
      cmd = COMMANDS[command_key]

      unless cmd
        error("I do not know that command: #{command_name}")
        say("Run spwn --help to see the commands I do know.")
        return 1
      end

      command_args = argv[1..] || []

      if command_args_include_help?(command_args)
        print_command_help(command_key)
        if git_command_exists?(command_key.to_s)
          git(command_key.to_s, *command_args)
        else
          say("")
          say("Git does not have a #{command_key} command, so there is no extra help to show beyond this.")
        end
        return 0
      end

      normalize_exit(cmd[:handler].call(command_args))
    end

    def normalize_exit(result)
      case result
      when Integer then result
      when true then 0
      else 1
      end
    end
  end
end
