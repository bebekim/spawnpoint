# Package spwn as the `spawnpoint` Ruby gem

**Status:** approved 2026-08-14
**Target release:** v0.2.0 (v0.1.0 is already tagged and released on GitHub)

## Goal

Students install the tool with `gem install spawnpoint` and run `spwn`. The gem
name `spwn` is taken on rubygems.org (unrelated 2012 gem); `spawnpoint` is free.
The executable stays `spwn` regardless of gem name.

## Decisions

- Publish to rubygems.org as `spawnpoint` (executable: `spwn`).
- Standard gem layout (hand-written gemspec, no `bundle gem` scaffold).
- The three review findings from the v0.1.0 review are fixed in this pass.

## Architecture

```
spawnpoint.gemspec      # hand-written; executables ["spwn"], bindir "exe"
Gemfile                 # gemspec + dev dependencies only
Rakefile                # default task: test
LICENSE                 # MIT
exe/spwn                # require "spawnpoint/cli"; exit Spawnpoint::CLI.run(ARGV)
lib/spawnpoint.rb       # entry point; requires version + cli
lib/spawnpoint/version.rb  # Spawnpoint::VERSION = "0.2.0"
lib/spawnpoint/cli.rb   # command table, dispatch, help (moved from bin/spwn)
lib/spawnpoint/synchronizer.rb  # moved from bin/__sync__.rb, class renamed
test/                   # minitest suite
```

- Module namespace is `Spawnpoint` (matches gem name convention).
- `bin/spwn` and `bin/__sync__.rb` are deleted; their code moves into `lib/`.
- No runtime dependencies — Ruby stdlib only (`fileutils`, `pathname`, `set`).

## Bug fixes folded in

1. **Exit-code propagation** — today `bin/spwn:322-323` calls the handler and
   always returns 0. New contract: handlers return an Integer exit code or a
   boolean (from `system`); the dispatcher normalizes to an Integer and
   `Spawnpoint::CLI.run` returns it. `spwn sync` misuse and git command failures
   exit non-zero.
2. **Marker merge** — `.spwn_synced_paths` is written as the union of previously
   known paths and this sync's paths (`known | new_known`), so files accepted in
   earlier lessons are not re-prompted later.
3. **Rename and cleanup** — `Syncronizer` → `Synchronizer`; the dead
   auto-replace branch and the no-op `next if child == ...` guards are removed.

## Packaging details

- Gemspec: name `spawnpoint`, version from `Spawnpoint::VERSION`, files from
  `git ls-files`, homepage `https://github.com/bebekim/spawnpoint`,
  license `MIT`, `required_ruby_version >= 3.0` (uses `argv[1..]`).
- `Gemfile` contains `gemspec` plus dev dependencies (minitest, rake).
- MIT `LICENSE` file added (gemspec requires a license for a clean push).

## Testing

Minitest (stdlib, no new runtime deps) in `test/`:

- CLI: unknown command exits 1; sync with missing args exits non-zero; `--help`
  exits 0.
- Synchronizer: fresh copy into a game folder; overwrite-with-confirmation;
  `--force`; rollback restores replaced files and removes created ones; marker
  union across two lessons (accepted file from lesson 1 is not re-prompted in
  lesson 3).

## README changes

- Install section: `gem install spawnpoint`, then `spwn --help`.
- Quick start for repo development: `ruby -Ilib exe/spwn --help`.
- Remove the PATH-shim section (obsolete — the gem puts `spwn` on PATH).
- Command mapping table and sync/rollback docs unchanged.

## Release flow (after implementation lands)

1. Commit, tag `v0.2.0`, push.
2. `gem build spawnpoint.gemspec` → `spawnpoint-0.2.0.gem`.
3. GitHub release `v0.2.0` (attach the `.gem` optional).
4. `gem push spawnpoint-0.2.0.gem` — requires the maintainer's rubygems.org
   credentials; run by the maintainer or with an API key provided at that time.

## Out of scope

- Homebrew formula, Scoop/WinGet manifests (README future-ideas list).
- The untracked pipeline/agent scaffolding (`spec.md`, `plan.json`,
  `pipeline-config.json`, `runs/`, `artifacts/`, `.agent-learning/`, `.claude/`)
  — left out of the gem via `git ls-files`; a separate decision whether they
  belong in the repo at all.
