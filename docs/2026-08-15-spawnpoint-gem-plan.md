# Package spwn as the `spawnpoint` Gem — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the spwn script into the publishable `spawnpoint` Ruby gem (executable `spwn`), fixing the exit-code, marker-merge, and `Syncronizer` naming bugs on the way.

**Architecture:** Standard gem layout: `exe/spwn` is a two-line executable; all logic moves from `bin/spwn` and `bin/__sync__.rb` into `lib/spawnpoint/*.rb` under the `Spawnpoint` namespace. Tests use minitest (stdlib).

**Tech Stack:** Ruby >= 3.0, rubygems, minitest, rake. No runtime dependencies.

**Spec:** `docs/2026-08-14-spawnpoint-gem-design.md`

## Global Constraints

- Gem name is `spawnpoint`; the installed executable is `spwn`.
- Module namespace is `Spawnpoint` everywhere (`Spawnpoint::CLI`, `Spawnpoint::Synchronizer`, `Spawnpoint::VERSION`).
- `Spawnpoint::VERSION` is `"0.2.0"`.
- No runtime dependencies — Ruby stdlib only (`fileutils`, `pathname`, `set`).
- All user-facing messages keep the existing child-friendly voice ("Oops: ...").
- Handler return contract: a handler returns an Integer exit code, or `true`/`false` from `system`; the dispatcher normalizes (`true`→0, `false`/`nil`→1) and `Spawnpoint::CLI.run` returns it.
- Do not commit the untracked pipeline scaffolding (`plan.json`, `pipeline-config.json`, etc.).

---

### Task 1: Gem skeleton and version

**Files:**
- Create: `spawnpoint.gemspec`
- Create: `Gemfile`
- Create: `Rakefile`
- Create: `LICENSE`
- Modify: `.gitignore`
- Create: `lib/spawnpoint/version.rb`
- Create: `test/test_helper.rb`
- Create: `test/test_version.rb`

**Interfaces:**
- Produces: `Spawnpoint::VERSION` (String, `"0.2.0"`), required via `require "spawnpoint/version"`. Tasks 2–4 and the gemspec depend on it.

- [ ] **Step 1: Write the failing test**

`test/test_helper.rb`:

```ruby
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
```

`test/test_version.rb`:

```ruby
require "test_helper"
require "spawnpoint/version"

class TestVersion < Minitest::Test
  def test_version_format
    assert_match(/\A\d+\.\d+\.\d+\z/, Spawnpoint::VERSION)
  end

  def test_version_is_0_2_0
    assert_equal "0.2.0", Spawnpoint::VERSION
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby -Itest test/test_version.rb`
Expected: FAIL with `cannot load such file -- spawnpoint/version` (LoadError)

- [ ] **Step 3: Write minimal implementation**

`lib/spawnpoint/version.rb`:

```ruby
# frozen_string_literal: true

module Spawnpoint
  VERSION = "0.2.0"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ruby -Itest test/test_version.rb`
Expected: PASS — 2 runs, 2 assertions, 0 failures

- [ ] **Step 5: Add gem packaging files**

`spawnpoint.gemspec`:

```ruby
# frozen_string_literal: true

require_relative "lib/spawnpoint/version"

Gem::Specification.new do |spec|
  spec.name = "spawnpoint"
  spec.version = Spawnpoint::VERSION
  spec.authors = ["bebekim"]
  spec.summary = "A child-friendly Git mask for learning game programming"
  spec.description = "spwn is a thin wrapper around Git that renames Git " \
                     "commands into friendlier, game-like language for kids " \
                     "learning game programming."
  spec.homepage = "https://github.com/bebekim/spawnpoint"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.chdir(__dir__) { `git ls-files -z`.split("\x0") }
  spec.bindir = "exe"
  spec.executables = ["spwn"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "source_code_uri" => "https://github.com/bebekim/spawnpoint",
    "rubygems_mfa_required" => "true"
  }
end
```

`Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "minitest", "~> 5.0"
gem "rake", "~> 13.0"
```

`Rakefile`:

```ruby
# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

task default: :test
```

`LICENSE` (MIT, year 2026, copyright holder "bebekim"):

```text
MIT License

Copyright (c) 2026 bebekim

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Append to `.gitignore` (keep the existing `.claude` / `.agent-learning` lines):

```text
*.gem
/pkg/
```

- [ ] **Step 6: Verify rake and gem build**

Run: `bundle install && rake`
Expected: PASS — version tests run green via rake

Run: `gem build spawnpoint.gemspec`
Expected: `Successfully built RubyGem` producing `spawnpoint-0.2.0.gem`. Note: `spec.executables` lists `spwn` which does not exist yet — that warning is fine at this point; Task 2 adds `exe/spwn`. Delete the built file afterwards: `rm spawnpoint-0.2.0.gem`.

- [ ] **Step 7: Commit**

```bash
git add spawnpoint.gemspec Gemfile Rakefile LICENSE .gitignore lib/spawnpoint/version.rb test/test_helper.rb test/test_version.rb
git commit -m "add gem skeleton with Spawnpoint::VERSION"
```

---

### Task 2: Move the CLI into `lib/spawnpoint/cli.rb`

**Files:**
- Create: `lib/spawnpoint/cli.rb`
- Create: `lib/spawnpoint.rb`
- Create: `exe/spwn`
- Create: `test/test_cli.rb`
- Reference (do not modify yet): `bin/spwn` — the code moves from here

**Interfaces:**
- Consumes: `Spawnpoint::VERSION` from Task 1.
- Produces: `Spawnpoint::CLI.run(argv)` → Integer exit code. This is the only public entry point; `exe/spwn` calls it. The `sync`/`rollback` handlers lazily `require_relative "synchronizer"` and call `Spawnpoint::Synchronizer.new.run(args)` / `.rollback(args)` — Task 3 provides that class.

- [ ] **Step 1: Write the failing tests**

`test/test_cli.rb`:

```ruby
require "test_helper"
require "spawnpoint/cli"

class TestCli < Minitest::Test
  def run_cli(argv)
    capture_io { @status = Spawnpoint::CLI.run(argv) }
    @status
  end

  def test_no_arguments_prints_help_and_exits_zero
    assert_equal 0, run_cli([])
  end

  def test_help_flag_exits_zero
    assert_equal 0, run_cli(["--help"])
  end

  def test_version_flag_exits_zero
    out, = capture_io { Spawnpoint::CLI.run(["--version"]) }
    assert_includes out, "0.2.0"
  end

  def test_unknown_command_exits_one
    assert_equal 1, run_cli(["teleport"])
  end

  def test_save_without_message_exits_one
    assert_equal 1, run_cli(["save"])
  end

  def test_commit_without_message_exits_one
    assert_equal 1, run_cli(["commit"])
  end

  def test_hop_without_arguments_exits_one
    assert_equal 1, run_cli(["hop"])
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby -Itest test/test_cli.rb`
Expected: FAIL with `cannot load such file -- spawnpoint/cli` (LoadError)

- [ ] **Step 3: Implement `lib/spawnpoint/cli.rb`**

This is the full content of `bin/spwn` reorganized into the `Spawnpoint::CLI` module, with the exit-code fix. Changes from `bin/spwn`: top-level methods become module functions (`extend self`); `VERSION` becomes `Spawnpoint::VERSION`; the sync/rollback handlers require `synchronizer` and use the renamed `Spawnpoint::Synchronizer`; `run` normalizes handler return values instead of always returning 0; the trailing `exit(run(ARGV))` script lines are gone (that moves to `exe/spwn`).

`lib/spawnpoint/cli.rb`:

```ruby
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
```

Note for the implementer: inside `COMMANDS` lambdas, `return` is replaced by `next` (a lambda `return` exits the defining scope; `next` returns from the lambda). Handlers that fail now `next nil`, which normalizes to exit code 1.

`lib/spawnpoint.rb`:

```ruby
# frozen_string_literal: true

require_relative "spawnpoint/version"
require_relative "spawnpoint/cli"
```

`exe/spwn`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "spawnpoint/cli"

exit Spawnpoint::CLI.run(ARGV)
```

Make it executable:

```bash
chmod +x exe/spwn
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `rake`
Expected: PASS — version + CLI tests green (9 runs, 0 failures)

- [ ] **Step 5: Smoke-test the executable from the repo**

Run: `ruby -Ilib exe/spwn --version`
Expected: prints `spwn v0.2.0`

Run: `ruby -Ilib exe/spwn teleport; echo "exit=$?"`
Expected: prints the unknown-command message and `exit=1`

Run: `ruby -Ilib exe/spwn --help | head -3`
Expected: help text starting with `spwn v0.2.0`

- [ ] **Step 6: Commit**

```bash
git add lib/spawnpoint.rb lib/spawnpoint/cli.rb exe/spwn test/test_cli.rb
git commit -m "move CLI into Spawnpoint::CLI with exit-code propagation"
```

---

### Task 3: Synchronizer with marker-merge fix

**Files:**
- Create: `lib/spawnpoint/synchronizer.rb`
- Create: `test/test_synchronizer.rb`
- Reference (do not modify): `bin/__sync__.rb` — the code moves from here

**Interfaces:**
- Consumes: nothing from other tasks (invoked lazily by `Spawnpoint::CLI`'s sync/rollback handlers from Task 2).
- Produces: `Spawnpoint::Synchronizer.new.run(argv)` → Integer (0 success, 1 usage error); `Spawnpoint::Synchronizer.new.rollback(argv)` → Integer. Side effects: copies files, writes `.spwn_synced_paths` marker and `.spwn_sync_backup/` in the target folder.

**Fixes relative to `bin/__sync__.rb`:**
1. Class renamed `Spwn::Syncronizer` → `Spawnpoint::Synchronizer`.
2. Marker is written as the union `known | new_known`, so paths accepted in earlier syncs are never forgotten.
3. Dead branch removed: when `dest.exist?`, the file is necessarily in `already_existed` (the target was scanned first), so the final `else` that copied silently is unreachable.
4. No-op guards `next if child == source` / `next if child == target` removed (`child` is always a file after the `child.file?` check; `source`/`target` are directories).

- [ ] **Step 1: Write the failing tests**

`test/test_synchronizer.rb`:

```ruby
require "test_helper"
require "tmpdir"
require "fileutils"
require "spawnpoint/synchronizer"

class TestSynchronizer < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @lesson = File.join(@dir, "lesson")
    @game = File.join(@dir, "game")
    FileUtils.mkdir_p(@lesson)
    FileUtils.mkdir_p(@game)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def write(folder, name, content)
    File.write(File.join(folder, name), content)
  end

  def sync(*extra)
    Spawnpoint::Synchronizer.new.run([@lesson, "--into", @game, *extra])
  end

  def marker_paths
    marker = File.join(@game, ".spwn_synced_paths")
    File.exist?(marker) ? File.readlines(marker).map(&:strip) : []
  end

  def test_run_without_arguments_exits_one
    capture_io { @status = Spawnpoint::Synchronizer.new.run([]) }
    assert_equal 1, @status
  end

  def test_run_without_into_exits_one
    capture_io { @status = Spawnpoint::Synchronizer.new.run([@lesson]) }
    assert_equal 1, @status
  end

  def test_run_with_missing_source_exits_one
    capture_io { @status = Spawnpoint::Synchronizer.new.run(["nope", "--into", @game]) }
    assert_equal 1, @status
  end

  def test_copies_new_files
    write(@lesson, "main.rb", "puts :hi")
    capture_io { @status = sync }
    assert_equal 0, @status
    assert_equal "puts :hi", File.read(File.join(@game, "main.rb"))
    assert_includes marker_paths, "main.rb"
  end

  def test_force_replaces_existing_file
    write(@game, "main.rb", "old")
    write(@lesson, "main.rb", "new")
    capture_io { @status = sync("--force") }
    assert_equal 0, @status
    assert_equal "new", File.read(File.join(@game, "main.rb"))
  end

  def test_rollback_restores_replaced_and_removes_created_files
    write(@game, "main.rb", "old")
    write(@lesson, "main.rb", "new")
    write(@lesson, "enemy.rb", "enemy code")
    capture_io { sync("--force") }
    assert_equal "new", File.read(File.join(@game, "main.rb"))

    capture_io { @status = Spawnpoint::Synchronizer.new.rollback(["--into", @game]) }
    assert_equal 0, @status
    assert_equal "old", File.read(File.join(@game, "main.rb"))
    refute File.exist?(File.join(@game, "enemy.rb"))
  end

  def test_rollback_without_backup_exits_one
    capture_io { @status = Spawnpoint::Synchronizer.new.rollback(["--into", @game]) }
    assert_equal 1, @status
  end

  def test_marker_keeps_paths_accepted_in_earlier_lessons
    # Lesson 1 introduces main.rb.
    write(@lesson, "main.rb", "v1")
    capture_io { sync }
    assert_includes marker_paths, "main.rb"

    # Lesson 2 introduces only enemy.rb; main.rb must not be forgotten.
    FileUtils.rm(File.join(@lesson, "main.rb"))
    write(@lesson, "enemy.rb", "enemy code")
    capture_io { sync }

    assert_includes marker_paths, "main.rb"
    assert_includes marker_paths, "enemy.rb"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby -Itest test/test_synchronizer.rb`
Expected: FAIL with `cannot load such file -- spawnpoint/synchronizer` (LoadError)

- [ ] **Step 3: Implement `lib/spawnpoint/synchronizer.rb`**

`lib/spawnpoint/synchronizer.rb`:

```ruby
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `rake`
Expected: PASS — all tests green, including `test_marker_keeps_paths_accepted_in_earlier_lessons` (the regression test for the marker-merge bug)

- [ ] **Step 5: Smoke-test sync through the CLI**

```bash
mkdir -p /tmp/spwn-lesson /tmp/spwn-game
echo "puts :hi" > /tmp/spwn-lesson/main.rb
ruby -Ilib exe/spwn sync /tmp/spwn-lesson --into /tmp/spwn-game
cat /tmp/spwn-game/main.rb
ruby -Ilib exe/spwn rollback --into /tmp/spwn-game
ls /tmp/spwn-game
ruby -Ilib exe/spwn sync; echo "exit=$?"
rm -rf /tmp/spwn-lesson /tmp/spwn-game
```

Expected: file copied, then removed by rollback; bare `spwn sync` prints usage and `exit=1`.

- [ ] **Step 6: Commit**

```bash
git add lib/spawnpoint/synchronizer.rb test/test_synchronizer.rb
git commit -m "add Spawnpoint::Synchronizer with marker-merge fix"
```

---

### Task 4: Delete `bin/`, rewrite README, final gem verification

**Files:**
- Delete: `bin/spwn`, `bin/__sync__.rb`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: the final repo state; a locally installable `spawnpoint-0.2.0.gem`.

- [ ] **Step 1: Delete the old script files**

```bash
git rm bin/spwn bin/__sync__.rb
```

- [ ] **Step 2: Rewrite the README install sections**

Make these edits to `README.md`:

1. Line 32, replace:

```markdown
Once Ruby and Git are installed, `spwn` itself is just one script.
```

with:

```markdown
Once Ruby and Git are installed, `spwn` itself is one `gem install` away.
```

2. Line 40, replace:

```markdown
- Easy to extend. The mapping between `spwn` commands and Git invocations lives inside
  `bin/spwn` so students and instructors can add or change commands without juggling extra files.
```

with:

```markdown
- Easy to extend. The mapping between `spwn` commands and Git invocations lives inside
  `lib/spawnpoint/cli.rb` so students and instructors can add or change commands in one place.
```

3. Replace the whole "Quick start" section (lines 43–56) with:

```markdown
## Quick start

Install the gem and run `spwn`:

```bash
gem install spawnpoint
spwn --help
```

To run the latest code from this repository instead:

```bash
ruby -Ilib exe/spwn --help
```
```

4. Replace the whole "Installing for a student" section (lines 58–101, including the macOS, Windows, and Compressed archive subsections) with:

```markdown
## Installing for a student

`spwn` is published as the `spawnpoint` gem, so installation is the same on macOS
and Windows once Ruby is installed:

```bash
gem install spawnpoint
```

This puts the `spwn` command on the PATH. Updating later is `gem update spawnpoint`.

If a machine cannot reach rubygems.org, build the gem from this repository and
install the file directly:

```bash
gem build spawnpoint.gemspec
gem install --local ./spawnpoint-0.2.0.gem
```
```

5. Line 139, replace:

```markdown
Run `ruby bin/spwn --help` for the current list.
```

with:

```markdown
Run `spwn --help` for the current list.
```

6. Line 163, replace:

```markdown
Open `bin/spwn` and look for the command mapping table near the top of the script.
```

with:

```markdown
Open `lib/spawnpoint/cli.rb` and look for the command mapping table near the top of the file.
```

- [ ] **Step 3: Run the full test suite**

Run: `rake`
Expected: PASS — all tests green

- [ ] **Step 4: Build and install the gem locally**

```bash
gem build spawnpoint.gemspec
GEM_HOME=/tmp/spwn-gem-test gem install --local ./spawnpoint-0.2.0.gem
GEM_HOME=/tmp/spwn-gem-test GEM_PATH=/tmp/spwn-gem-test /tmp/spwn-gem-test/bin/spwn --version
GEM_HOME=/tmp/spwn-gem-test GEM_PATH=/tmp/spwn-gem-test /tmp/spwn-gem-test/bin/spwn --help | head -3
```

Expected: build succeeds; installed `spwn` prints `spwn v0.2.0` and the help text. Then clean up:

```bash
rm -rf /tmp/spwn-gem-test spawnpoint-0.2.0.gem
```

- [ ] **Step 5: Verify the gem contents**

```bash
gem build spawnpoint.gemspec
gem spec spawnpoint-0.2.0.gem files
```

Expected: the file list includes `exe/spwn`, `lib/spawnpoint.rb`, `lib/spawnpoint/version.rb`, `lib/spawnpoint/cli.rb`, `lib/spawnpoint/synchronizer.rb`, `README.md`, `LICENSE` — and does NOT include `bin/spwn`, `bin/__sync__.rb`, or the untracked pipeline files. Clean up: `rm spawnpoint-0.2.0.gem`.

- [ ] **Step 6: Commit**

```bash
git add -A bin README.md
git commit -m "replace bin/ scripts with the spawnpoint gem layout"
```

---

## Follow-up (not part of this plan — maintainer steps)

1. Tag `v0.2.0`, push to GitHub, create the GitHub release.
2. `gem build spawnpoint.gemspec && gem push spawnpoint-0.2.0.gem` — needs the maintainer's rubygems.org credentials (MFA is required per the gemspec metadata).
