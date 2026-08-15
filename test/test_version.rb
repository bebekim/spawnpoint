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
