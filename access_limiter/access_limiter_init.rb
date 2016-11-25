Userdata.new.shared_mutex = Mutex.new :global => true
Userdata.new.shared_cache = Cache.new :namespace => "access_limiter"
Userdata.new.shared_config_store = Cache.new :filename => "/access_limiter/max_clients_handler.lmc"

# because it may have already increment counter
Userdata.new.shared_cache.clear

class AccessLimiter
  attr_reader :counter_key
  attr_accessor :current_time

  def initialize(r, cache, config)
    @cache = cache
    raise "config[:target] is nil" if config[:target].nil?
    config[:expire_time] = 600 if config[:expire_time].nil?
    @config = config
    @counter_key = config[:target].to_s
    @current_time = Time.new.localtime.to_i
  end

  def cleanup_counter
    cnt = current
    ctime = create_time
    if cnt > 0 && ctime > 0 && (ctime + @config[:expire_time]) < @current_time
      @cache[@counter_key] = "0"
      @cache["create_time_#{@counter_key}"] = ctime.to_s
      true
    else
      false
    end
  end

  def create_time
    @cache["create_time_#{@counter_key}"].to_i
  end

  def current
    @cache[@counter_key].to_i
  end

  def increment
    cnt = current + 1
    @cache["create_time_#{@counter_key}"] = @current_time.to_s if cnt == 1
    @cache[@counter_key] = cnt.to_s
    cnt
  end

  def decrement
    cnt = current - 1
    cnt = 0 if cnt < 0
    @cache[@counter_key] = cnt.to_s
    cnt
  end
end

class MaxClientsHandler
  attr_accessor :current_time

  def initialize(access_limiter, config_store)
    #Userdata.new.shared_config_store ||= Cache.new :filename => config_store_path unless Userdata.new.shared_config_store
    @access_limiter = access_limiter
    @config_raw = config_store.get(@access_limiter.counter_key)
  end

  # convert to hash limit condition of json
  # @return [Hash] limit condition
  def config
    @_config ||= JSON.parse(@config_raw) if @config_raw
  end

  def max_clients
    config ? config["max_clients"].to_i : 0
  end

  # corresponds the limit conditions?
  # @return [true, false] matched limit conditions
  def limit?
    max_clients? && time_slots?(config["time_slots"])
  end

  def current_time
    unless @current_time
      c = Time.new.localtime
      @current_time = c.hour.to_s + c.min.to_s
    end
    @current_time.to_i
  end

  # current connection number has reached the limit conditions from access_limiter?
  # @return [true, false] reached limit concurrent connections
  def max_clients?
    max_clients != 0 && max_clients < @access_limiter.current
  end

  # request time match a limit conditions of time slots
  # @return [true, false] matched limit conditions of time slots
  def time_slots?(time_slots)
    return true if time_slots.nil? || time_slots.size == 0
    time_slots.find do |t|
      t["begin"].to_i <= current_time && t["end"].to_i >= current_time
    end.nil? ? false : true
  end
end

if Object.const_defined?(:MTest)
  class TestAccessLimiter < MTest::Unit::TestCase
    def setup
      @access_limiter = AccessLimiter.new(
        nil,
        Userdata.new.shared_cache,
        :target => "/var/www/html/phpinfo.php"
      )
    end

    def test_cleanup_counter
      Userdata.new.shared_cache.clear

      @access_limiter.current_time = Time.local(2016, 01, 01, 10, 30, 00).to_i   # 2016/1/1 10:30:00 1451611800 expire: 600sec
      @access_limiter.increment
      @access_limiter.increment
      assert_false(@access_limiter.cleanup_counter)
      assert_equal(2, @access_limiter.current)

      @access_limiter.current_time = Time.local(2016, 01, 01, 10, 40, 01).to_i   # 2016/1/1 10:40:01 1451612401 expire: 600sec
      @access_limiter.increment
      assert(@access_limiter.cleanup_counter)
      assert_equal(0, @access_limiter.current)

      Userdata.new.shared_cache.clear

      a =  AccessLimiter.new(
        nil,
        Userdata.new.shared_cache,
        :target => "/var/www/html/phpinfo.php",
        :expire_time => 1200
      )
      a.current_time = Time.local(2016, 01, 01, 10, 30, 00).to_i   # 2016/1/1 10:30:00 1451611800 expire: 1200sec
      a.increment
      a.increment
      assert_false(a.cleanup_counter)
      assert_equal(2, a.current)

      a.current_time = Time.local(2016, 01, 01, 10, 40, 01).to_i   # 2016/1/1 10:40:01 1451612401 expire: 1200sec
      a.increment
      assert_false(a.cleanup_counter)
      assert_equal(3, a.current)

      a.current_time = Time.local(2016, 01, 01, 10, 50, 01).to_i   # 2016/1/1 10:50:01 1451613001 expire: 1200sec
      a.increment
      assert(a.cleanup_counter)
      assert_equal(0, a.current)
    end

    def test_counter
      Userdata.new.shared_cache.clear

      @access_limiter.increment
      @access_limiter.increment
      assert_equal(2, @access_limiter.current)

      @access_limiter.decrement
      assert_equal(1, @access_limiter.current)

      @access_limiter.decrement
      assert_equal(0, @access_limiter.current)
    end

    def terdown
      Cache.drop :namespace => "access_limiter"
    end
  end

  class TestMaxClientsHandler < MTest::Unit::TestCase
    def setup
      # Regist limit condition for max_clients_handler
      @config_store_path = "/var/tmp/max_clients_handler.lmc"
      @config_store = Cache.new :filename => @config_store_path
      @config_store.set(
        "/var/www/html/always.php",
        '{
          "max_clients" : 2,
          "time_slots" : null
        }'
      )
      @config_store.set(
        "/var/www/html/peaktime.php",
        '{
          "max_clients" : 2,
          "time_slots" : [
            { "begin" : 900, "end" : 1300 },
            { "begin" : 1700, "end" : 2200 }
          ]
        }'
      )

      @access_limiter = AccessLimiter.new(
        nil,
        Userdata.new.shared_cache,
        :target => "/var/www/html/always.php"
      )
      @max_clients_handler = MaxClientsHandler.new(
        @access_limiter,
        @config_store
      )

      @access_limiter_enable_timeslots = AccessLimiter.new(
        nil,
        Userdata.new.shared_cache,
        :target => "/var/www/html/peaktime.php"
      )
      @max_clients_handler_enable_timeslots = MaxClientsHandler.new(
        @access_limiter_enable_timeslots,
        @config_store
      )

      @access_limiter_unlimited = AccessLimiter.new(
        nil,
        Userdata.new.shared_cache,
        :target => "/var/www/html/unlimited.php"
      )
      @max_clients_handler_unlimited = MaxClientsHandler.new(
        @access_limiter_unlimited,
        @config_store
      )
    end

    def test_limit
      Userdata.new.shared_cache.clear

      # max_clients:2 current:0 always
      assert_false(@max_clients_handler.limit?)

      # max_clients:2 current:1 always
      @access_limiter.increment
      assert_false(@max_clients_handler.limit?)

      # max_clients:2 current:2 always
      @access_limiter.increment
      assert_false(@max_clients_handler.limit?)

      # max_clients:2 current:3 always
      @access_limiter.increment
      assert(@max_clients_handler.limit?)

      # max_clients:2 current:3 9:00-13:00/17:00-22:00
      @access_limiter_enable_timeslots.increment
      @access_limiter_enable_timeslots.increment
      @access_limiter_enable_timeslots.increment
      @max_clients_handler_enable_timeslots.current_time = 800
      assert_false(@max_clients_handler_enable_timeslots.limit?)
      # time of enable
      @max_clients_handler_enable_timeslots.current_time = 900
      assert(@max_clients_handler_enable_timeslots.limit?)
    end

    def test_max_clients
      Userdata.new.shared_cache.clear

      # max_clients:2 current:0
      assert_false(@max_clients_handler.max_clients?)

      # max_clients:2 current:1
      @access_limiter.increment
      assert_false(@max_clients_handler.max_clients?)

      # max_clients:2 current:2
      @access_limiter.increment
      assert_false(@max_clients_handler.max_clients?)

      # max_clients:2 current:3
      @access_limiter.increment
      assert(@max_clients_handler.max_clients?)
    end

    def test_time_slots
      sample_time_slots = [
        { "begin" => 900, "end" => 1300 },
        { "begin" => 1700, "end" => 2200 },
      ]

      @max_clients_handler.current_time = 1000
      assert(@max_clients_handler.time_slots?(nil))

      @max_clients_handler_enable_timeslots.current_time = 800
      assert_false(@max_clients_handler_enable_timeslots.time_slots?(sample_time_slots))

      @max_clients_handler_enable_timeslots.current_time = 900
      assert(@max_clients_handler_enable_timeslots.time_slots?(sample_time_slots))

      @max_clients_handler_enable_timeslots.current_time = 1000
      assert(@max_clients_handler_enable_timeslots.time_slots?(sample_time_slots))

      @max_clients_handler_enable_timeslots.current_time = 1400
      assert_false(@max_clients_handler_enable_timeslots.time_slots?(sample_time_slots))

      @max_clients_handler_enable_timeslots.current_time = 2300
      assert_false(@max_clients_handler_enable_timeslots.time_slots?(sample_time_slots))
    end

    def terdown
      Cache.drop :namespace => "access_limiter"
      Cache.drop :filename => @config_store_path
    end
  end

  MTest::Unit.new.run
end
