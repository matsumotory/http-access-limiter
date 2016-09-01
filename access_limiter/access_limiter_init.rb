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
    localtime = Time.new.localtime
    time = localtime.hour.to_s + localtime.min.to_s
    @request_time = time.to_i

    if config[:target].nil?
      raise "config[:target] is nil"
    end
    @counter_key = config[:target].to_s

    @limit_info = nil
    @key_exist  = false

    val = kvs.get(@counter_key)
    unless val.nil?
      hash = JSON.parse(val)
      if hash.is_a?(Hash)
        @limit_info = hash
        @key_exist  = true
      end
    end
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
    val = cache[@counter_key].to_i + 1
    cache[@counter_key] = val.to_s
    val
  end

  def decrement
    cur = cache[@counter_key]
    cnt = cur.to_i - 1
    if cnt < 1
      unless cur.nil?
        cache.delete @counter_key
      end
    else
      cache[@counter_key] = cnt.to_s
    end
    cnt
  end

  def key_exist?
    @key_exist
  end

  def max_clients
    @limit_info["max_clients"] if @key_exist
  end

  def time_slots
    @limit_info["time_slots"] if @key_exist
  end

  def time_slots_match?
    return false unless @key_exist

    time_slots = @limit_info["time_slots"]
    return true if time_slots.size == 0

    time_slots.each do |time_slot|
      begin_time = time_slot["begin"].to_i
      end_time   = time_slot["end"].to_i
      if begin_time <= @request_time && end_time >= @request_time
        return true
      end
    end
    false
  end

  def limit?
    return false unless @key_exist
    if @limit_info["max_clients"].to_i < current
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
      @access_limiter.increment
      @access_limiter.increment
      @access_limiter.increment
      @access_limiter.decrement
      assert_equal(2, @access_limiter.current)
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

