Userdata.new.shared_mutex = Mutex.new :global => true
Userdata.new.shared_cache = Cache.new :namespace => "access_limiter"

class AccessLimiter
  def initialize config
    @cache = Userdata.new.shared_cache
    @config = config
    if config[:target].nil?
      raise "config[:target] is nil"
    end
    @counter_key = config[:target].to_s
  end
  def current
    @cache[@counter_key].to_i
  end
  def increment
    val = @cache[@counter_key].to_i + 1
    @cache[@counter_key] = val.to_s
    val
  end
  def decrement
    cur = @cache[@counter_key]
    cnt = cur.to_i - 1
    if cnt < 1
      unless cur.nil?
        @cache.delete @counter_key
      end
    else
      @cache[@counter_key] = cnt.to_s
    end
    cnt
  end
end

if Object.const_defined?(:MTest)
  class TestAccessLimiter < MTest::Unit::TestCase
    def setup
      @access_limiter = AccessLimiter.new(
        :target => "/var/www/html/phpinfo.php"
      )
    end

    def test_increment
      @access_limiter.increment
      @access_limiter.increment
      assert_equal(2, @access_limiter.current)
    end

    def test_decrement
      @access_limiter.decrement
      assert_equal(1, @access_limiter.current)
    end

    def terdown
      Cache.drop :namespace => "access_limiter"
    end
  end

  MTest::Unit.new.run
end
