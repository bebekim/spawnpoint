# spwn

A child-friendly text interface for Git, aimed at 12-year-olds learning to program games.

`spwn` is a thin wrapper around Git that renames the commands into game-like language and
presents them through a simple command-line interface. It is not a replacement for Git; it is
a mask that makes the vocabulary friendlier while still calling Git under the hood.

## Before you start

`spwn` needs two things already installed: **Ruby** and **Git**. It does not install either of
them for you.

Check whether you have them by running:

```bash
ruby --version
git --version
```

If both commands print a version number, you are ready to go. If one of them says "command not
found", install the missing piece first.

- **Ruby** — from `https://www.ruby-lang.org/`. On Windows, the RubyInstaller2 downloads are at
  `https://github.com/oneclick/rubyinstaller2/releases`; pick the latest release and use the
  installer that matches your machine (the plain installer is enough if you do not need to compile
  C extensions).
- **Git** — from `https://git-scm.com/`. On macOS, Git may already be available; if not,
  `xcode-select --install` is one common way to get it. On Windows, the Git installer from
  `git-scm.com` puts Git on your PATH.

Once Ruby and Git are installed, `spwn` itself is one `gem install` away.

## Philosophy

- Friendlier words, not a new VCS. Git still does the real work.
- Thin confirmations. Dangerous operations still go through Git's normal behavior; we do not
  add extra popups unless a command genuinely needs a "are you sure?" step.
- Easy to extend. The mapping between `spwn` commands and Git invocations lives inside
  `lib/spawnpoint/cli.rb` so students and instructors can add or change commands in one place.
- Standard Git still works. Students can always fall back to `git` directly when they are ready.

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

## Command mapping

`spwn` is a thin rename layer over Git. The table below shows the main mappings. When a student
is ready, they can use the Git command directly instead.

| `spwn` command | Git command(s) | What it does |
| --- | --- | --- |
| `spwn init` | `git init` | Start a new project folder that Git can track. |
| `spwn add <file>` | `git add <file>` | Tell Git which files to include in the next snapshot. |
| `spwn add .` | `git add .` | Stage all changed files in the current folder. |
| `spwn add -A` | `git add -A` | Stage all changed files, including deletions. |
| `spwn commit -m 'note'` | `git commit -m 'note'` | Save the files you have already picked. |
| `spwn save -m 'note'` | `git add .` then `git commit -m 'note'` | Stage changed files and commit them together. |
| `spwn look` | `git status` | See what is going on in your project right now. |
| `spwn compare` | `git diff` | See what changed since the last snapshot. |
| `spwn history` | `git log` | Replay the story of your project, one snapshot at a time. |
| `spwn hop <branch>` | `git switch <branch>` | Jump to another universe (branch). |
| `spwn hop -- <branch> <file>` | `git restore --source <branch> -- <file>` | Bring a file back from another snapshot. |
| `spwn upload` | `git push` | Send your snapshots to the shared project space. |
| `spwn download` | `git pull` | Fetch new snapshots from the shared project space and combine them with yours. |
| `spwn sync <lesson> --into <game>` | — | Copy lesson files into a game folder, replacing matching files when confirmed. |
| `spwn rollback --into <game>` | — | Undo the most recent lesson sync: restore replaced files and remove newly copied files. |

A few notes about the mapping:

- `spwn save` is the only command that runs more than one Git command. It stages the current
  folder and then commits, so students can think of it as "save everything with a note".
- `spwn hop --` is the file-restore form. The branch must be named explicitly, for example
  `spwn hop -- feature my_level.rb`. If you give only a file name and that file already exists on
  the current branch, `spwn` restores it from there; otherwise it asks you to name the source
  branch.
- `spwn` does not hide Git's errors on purpose. If something goes wrong, the error still comes
  from Git, so students eventually see the real message behind the friendly name.

## Commands

Run `spwn --help` for the current list. The first version focuses on the commands
students need while following a single-player course:

- `spwn save` — stage changed files and commit them together.
- `spwn add` — stage files. Supports individual paths, `.`, and `-A`.
- `spwn commit` — commit already staged changes.
- `spwn look` — inspect the current state.
- `spwn compare` — show what changed.
- `spwn history` — show recent commits.
- `spwn hop` — switch branches or restore files.
- `spwn upload` — push to a remote.
- `spwn download` — fetch and integrate from a remote.
- `spwn init` — start a new project.
- `spwn sync <lesson> --into <game>` — copy lesson files into a game folder. Use `--force` to
  replace matching files without asking.
- `spwn rollback --into <game>` — undo the most recent sync. Files that existed before the sync
  are restored, files created by the sync are removed, and unrelated game files are left alone.

Branch-related commands are framed as "multiverse" because branches feel like parallel universes
to a 12-year-old. `spwn hop` is the entry point for both switching branches and restoring files;
the script explains the difference in its help text.

## Extending the mapping

Open `lib/spawnpoint/cli.rb` and look for the command mapping table near the top of the file. Each entry
describes:

- the `spwn` subcommand name,
- the help text shown to students,
- the Git command or commands to run,
- any flags or argument handling.

To add a new command, add a row to that table and, if needed, a small amount of argument handling
code nearby. To change how an existing command works, edit its row. You do not need to touch the
main dispatch logic unless you are changing how arguments flow through the script.

## Relationship to the course

This tool is intentionally small. It is designed to be used alongside the course materials, not
to become a project of its own. If a lesson needs a new Git workflow, add the corresponding
`spwn` command rather than building a separate tool.
