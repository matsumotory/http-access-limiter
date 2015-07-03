Userdata.new.shared_mutex = Mutex.new :global => true

class AccessLimitter
  def initialize r, c, config
    @r = r
    @cache = c
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
    @cache[@counter_key] = (@cache[@counter_key].to_i + 1).to_s
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
  end
end

