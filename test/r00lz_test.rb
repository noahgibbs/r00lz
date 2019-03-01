require "test_helper"

class PostsController < R00lz::Controller
  def speculate
    "Whoah, man..."
  end
end

class R00lzTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::R00lz::VERSION
  end

  def test_new_controller_action
    env = { "PATH_INFO" => "/posts/speculate", "QUERY_STRING" => "" }
    assert_equal 200, ::R00lz::App.new.call(env)[0]
  end
end
