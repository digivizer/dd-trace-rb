require 'minitest'
require 'minitest/autorun'
require 'ddtrace'
require 'elasticsearch/transport'
require 'redis'

class MonkeyTest < Minitest::Test
  def test_autopatch_modules
    assert_equal({ elasticsearch: true, http: true, redis: true }, Datadog::Monkey.autopatch_modules)
  end

  def test_patch_module
    # because of this test, this should be a separate rake task,
    # else the module could have been already imported in some other test
    assert_equal(false, Datadog::Contrib::Elasticsearch::Patcher.patched?)
    assert_equal(false, Datadog::Contrib::HTTP::Patcher.patched?)
    assert_equal(false, Datadog::Contrib::Redis::Patcher.patched?)
    assert_equal({ elasticsearch: false, http: false, redis: false }, Datadog::Monkey.get_patched_modules())

    Datadog::Monkey.patch_module(:redis)
    assert_equal(false, Datadog::Contrib::Elasticsearch::Patcher.patched?)
    assert_equal(false, Datadog::Contrib::HTTP::Patcher.patched?)
    assert_equal(true, Datadog::Contrib::Redis::Patcher.patched?)
    assert_equal({ elasticsearch: false, http: false, redis: true }, Datadog::Monkey.get_patched_modules())

    # now do it again to check it's idempotent
    Datadog::Monkey.patch_module(:redis)
    assert_equal(false, Datadog::Contrib::Elasticsearch::Patcher.patched?)
    assert_equal(false, Datadog::Contrib::HTTP::Patcher.patched?)
    assert_equal(true, Datadog::Contrib::Redis::Patcher.patched?)
    assert_equal({ elasticsearch: false, http: false, redis: true }, Datadog::Monkey.get_patched_modules())

    Datadog::Monkey.patch(elasticsearch: true, redis: true)
    assert_equal(true, Datadog::Contrib::Elasticsearch::Patcher.patched?)
    assert_equal(false, Datadog::Contrib::HTTP::Patcher.patched?)
    assert_equal(true, Datadog::Contrib::Redis::Patcher.patched?)
    assert_equal({ elasticsearch: true, http: false, redis: true }, Datadog::Monkey.get_patched_modules())

    Datadog::Monkey.patch_all()
    assert_equal(true, Datadog::Contrib::Elasticsearch::Patcher.patched?)
    assert_equal(true, Datadog::Contrib::HTTP::Patcher.patched?)
    assert_equal(true, Datadog::Contrib::Redis::Patcher.patched?)
    assert_equal({ elasticsearch: true, http: true, redis: true }, Datadog::Monkey.get_patched_modules())
  end
end
