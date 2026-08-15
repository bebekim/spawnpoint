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
