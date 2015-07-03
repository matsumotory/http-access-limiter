####
threshold = 2
####

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
  limit = AccessLimitter.new r, cache, config
  # process-shared lock
  timeout = global_mutex.try_lock_loop(50000) do
    begin
      limit.increment
      Server.errlogger Server::LOG_NOTICE, "access_limitter: file:#{r.filename} counter:#{limit.current}"
      if limit.current > threshold
        Server.errlogger Server::LOG_NOTICE, "access_limitter: file:#{r.filename} reached threshold: #{threshold}: return #{Server::HTTP_SERVICE_UNAVAILABLE}"
        Server.return Server::HTTP_SERVICE_UNAVAILABLE
      end
    rescue => e
      raise "AccessLimitter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
  if timeout                                                                     
    Server.errlogger Server::LOG_NOTICE, "access_limitter: get timeout lock, #{r.filename}"
  end                                                                            
end
