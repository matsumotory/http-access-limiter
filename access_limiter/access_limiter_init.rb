Userdata.new.shared_mutex = Mutex.new :global => true
Userdata.new.shared_cache = Cache.new :namespace => "access_limiter"
if Object.const_defined?(:MTest)
  Userdata.new.shared_kvs = Cache.new :filename => "/var/tmp/test.lmc"
else
  Userdata.new.shared_kvs = Cache.new :filename => "/access_limiter/limit_list.lmc"
end

class AccessLimiter
  attr_accessor :request_time

  def initialize(config)
    if config[:target].nil?
      raise "config[:target] is nil"
    end
    @counter_key = config[:target].to_s
  end

  def request_time
    unless @request_time
      localtime = Time.new.localtime
      @request_time = (localtime.hour.to_s + localtime.min.to_s).to_i
    end
    @request_time
  end

  def limit_info_json
    @_limit_info_json ||= kvs[@counter_key]
  end

  def limit_info
    @_limit_info ||= JSON.parse(limit_info_json)
  end

  def cache
    @_cache ||= Userdata.new.shared_cache
  end

  def kvs
    @_kvs ||= Userdata.new.shared_kvs
  end

  def current
    cache[@counter_key].to_i
  end

  def increment
    cache[@counter_key] = (current + 1).to_s
  end

  def decrement
    cnt = current - 1
    if cnt < 1
      unless current.nil?
        cache.delete @counter_key
      end
    else
      cache[@counter_key] = cnt.to_s
    end
    cnt
  end


  def key_exist?
    @_key_exist ||= limit_info_json.nil? ? false : true
  end

  def max_clients
    @_max_clients ||= limit_info["max_clients"].to_i if key_exist?
  end

  def time_slots
    @_time_slots ||= limit_info["time_slots"] if key_exist?
  end

  def time_slots_match?
    return false unless key_exist?

    return true if time_slots.size == 0

    time_slots.each do |time_slot|
      begin_time = time_slot["begin"].to_i
      end_time   = time_slot["end"].to_i
      if begin_time <= request_time && end_time >= request_time
        return true
      end
    end
    false
  end

  def limit?
    return false unless key_exist?
    if max_clients < current
      return true if time_slots_match?
    end
    false
  end
end

if Object.const_defined?(:MTest)
  class TestAccessLimiter < MTest::Unit::TestCase

    def setup
      # write test data
      kvs = Cache.new :filename => "/var/tmp/test.lmc"
      kvs.set(
        "/var/www/html/test1.php",
        '{
          "max_clients" : 1,
          "time_slots" : [
            { "begin" : 900, "end" : 1000 },
            { "begin" : 1700, "end" : 2000 }
          ]
        }'
      )
      kvs.set(
        "/var/www/html/test2.php",
        '{
          "max_clients" : 1,
          "time_slots" : []
        }'
      )
      kvs.close

      # create test request
      #request_time = Date.today.strformat("%H%M")
      @access_limiter = AccessLimiter.new({
        :target => "/path/to/hoge.php",
      })

      @test1 = AccessLimiter.new({
        :target => "/var/www/html/test1.php",
      })

      @test2 = AccessLimiter.new({
        :target => "/var/www/html/test2.php",
      })
    end

    def test_localmemcache
      @test1.increment
      @test1.increment
      @test1.increment
      @test1.decrement
      assert_equal(2, @test1.current)
    end

    def test_key_exist
      assert_false(@access_limiter.key_exist?)
      assert      (@test1.key_exist?)
      assert      (@test2.key_exist?)
    end

    def test_max_clients
      assert_equal(nil, @access_limiter.max_clients)
      assert_equal(1, @test1.max_clients)
      assert_equal(1, @test2.max_clients)
    end

    def test_time_slots
      assert_equal(nil, @access_limiter.time_slots)
      assert_equal([ { "begin" => 900, "end" => 1000 }, { "begin" => 1700, "end" => 2000 } ], @test1.time_slots)
      assert_equal([], @test2.time_slots)
    end

    def test_time_slots_match
      assert_false(@access_limiter.time_slots_match?)
      @test1.request_time = 930
      assert_true(@test1.time_slots_match?)
      @test1.request_time = 1200
      assert_false(@test1.time_slots_match?)
      assert      (@test2.time_slots_match?)
    end

    def test_limit
      assert_false(@access_limiter.limit?)
      assert_false(@test2.limit?)
      @test2.increment
      assert_false(@test2.limit?)
      @test2.increment
      assert      (@test2.limit?)
    end

    def teardown
      # cache clear
      Userdata.new.shared_cache.clear

      # delete test kvs file
      if File.exist?("/var/tmp/test.lmc")
        File.delete("/var/tmp/test.lmc")
      end
    end
  end

  MTest::Unit.new.run
end

