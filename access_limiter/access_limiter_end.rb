Server = get_server_class
r = Server::Request.new
cache = Userdata.new.shared_cache
global_mutex = Userdata.new.shared_mutex

file = r.filename

config = {
  # access limmiter by target
  :target => file,
}

unless r.sub_request?
  limit = AccessLimiter.new config
  # process-shared lock
  global_mutex.try_lock_loop(50000) do
    begin
      limit.decrement
      Server.errlogger Server::LOG_NOTICE, "access_limiter_end: decrement: #{file} #{limit.current}"
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
end
