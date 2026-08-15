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
