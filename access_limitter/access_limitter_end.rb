Server = get_server_class
r = Server::Request.new
cache = Userdata.new.shared_cache
global_mutex = Userdata.new.shared_mutex

file = r.filename

config = {
  # access limmiter by target
  :target => file,
}

# ngx_mruby doesn't have sub_request method                                      
#unless r.sub_request?
  limit = AccessLimitter.new r, cache, config
  # process-shared lock
  global_mutex.try_lock_loop(50000) do
    begin
      limit.decrement
      Server.errlogger Server::LOG_NOTICE, "access_limitter_end: #{r.filename} #{limit.current}"
    rescue => e
      raise "AccessLimitter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
#end
