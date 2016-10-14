Userdata.new.shared_mutex = Mutex.new :global => true
Userdata.new.shared_cache = Cache.new :namespace => "access_limiter"

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

  # delete old counter
  # to keep the consistency when unintended woker process down
  # @return [Fixnum] deleted count number
  def keep_inconsistency
    c = counter
    old_size = c.size
    if c.size > 0
      c.delete_if { |v| v < @current_time - @config[:expire_time].to_i }
      @cache[@counter_key] = c.to_s
    end
    old_size - c.size
  end

  def counter
    cur_raw = @cache[@counter_key]
    begin
      cur = JSON.parse(cur_raw)
    rescue
      cur = Array.new
    end
  end

  def current
    counter.size
  end

  def increment
    c = counter
    c.push(@current_time)
    @cache[@counter_key] = c.to_s
    c.size
  end

  def decrement
    c = counter
    c.pop
    cnt = c.size
    if cnt < 1
      unless c.nil?
        @cache.delete @counter_key
      end
    else
      @cache[@counter_key] = c.to_s
    end
    cnt
  end
end

class MaxClientsHandler
  attr_accessor :current_time

  def initialize(access_limiter, config_store_path)
    Userdata.new.shared_config_store ||= Cache.new :filename => config_store_path unless Userdata.new.shared_config_store
    @access_limiter = access_limiter
    @config_raw = Userdata.new.shared_config_store.get(@access_limiter.counter_key)
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
    return true if time_slots.size == 0
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

    def test_counter
      @access_limiter.increment
      @access_limiter.increment
      assert_equal(2, @access_limiter.current)

      @access_limiter.decrement
      assert_equal(1, @access_limiter.current)

      @access_limiter.decrement
    end

    def test_keep_inconsistency
      @access_limiter.current_time = Time.local(2016, 01, 01, 10, 30, 00).to_i   # 2016/1/1 10:30:00 1451611800 expire: 600sec
      @access_limiter.increment
      @access_limiter.increment
      assert_equal(0, @access_limiter.keep_inconsistency)
      assert_equal(2, @access_limiter.current)

      @access_limiter.current_time = Time.local(2016, 01, 01, 10, 40, 01).to_i   # 2016/1/1 10:40:01 1451612401 expire: 600sec
      assert_equal(2, @access_limiter.keep_inconsistency)
      assert_equal(0, @access_limiter.current)

      # change expire_time
      a = AccessLimiter.new(
        nil,
        Userdata.new.shared_cache,
        :target => "/var/www/html/phpinfo.php",
        :expire_time => 1200
      )
      a.current_time = Time.local(2016, 01, 01, 10, 30, 00).to_i   # 2016/1/1 10:30:00 1451611800 expire: 1200sec
      a.increment
      a.increment
      assert_equal(0, a.keep_inconsistency)
      assert_equal(2, a.current)

      a.current_time = Time.local(2016, 01, 01, 10, 40, 01).to_i   # 2016/1/1 10:40:01 1451612401 expire: 1200sec
      assert_equal(0, a.keep_inconsistency)
      assert_equal(2, a.current)

      a.current_time = Time.local(2016, 01, 01, 10, 50, 01).to_i   # 2016/1/1 10:50:01 1451613001 expire: 1200sec
      assert_equal(2, a.keep_inconsistency)
      assert_equal(0, a.current)
    end

    def terdown
      Cache.drop :namespace => "access_limiter"
    end
  end

  class TestMaxClientsHandler < MTest::Unit::TestCase
    def setup
      # Regist limit condition for max_clients_handler
      @config_store = "/var/tmp/max_clients_handler.lmc"
      c = Cache.new :filename => @config_store
      c.set(
        "/var/www/html/always.php",
        '{
          "max_clients" : 2,
          "time_slots" : []
        }'
      )
      c.set(
        "/var/www/html/peaktime.php",
        '{
          "max_clients" : 2,
          "time_slots" : [
            { "begin" : 900, "end" : 1300 },
            { "begin" : 1700, "end" : 2200 }
          ]
        }'
      )
      c.close

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
      assert(@max_clients_handler.time_slots?(Array.new))

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
      Cache.drop @config_store
    end
  end

  MTest::Unit.new.run
end
