Server = get_server_class
request = Server::Request.new

unless request.sub_request?
  global_mutex = Userdata.new.shared_mutex
  filename = request.filename

  config = {
    :target => filename,
  }

  al = AccessLimiter.new(config)

  if al.key_exist?
    timeout = global_mutex.try_lock_loop(50000) do
      begin
        al.increment
        Server.errlogger Server::LOG_DEBUG, "access_limiter: increment: file: #{filename} counter: #{al.current} max_clients: #{al.max_clients} time_slot: #{al.time_slots}"
        if al.limit?
          Server.errlogger Server::LOG_NOTICE, "access_limiter: limit: file: #{filename} return: 503"
          Server.return Server::HTTP_SERVICE_UNAVAILABLE
        end
      rescue => e
        raise "access_limiter: failed: #{e}"
      ensure
        global_mutex.unlock
      end
    end
    if timeout
      Server.errlogger Server::LOG_NOTICE, "access_limiter: failed: file: #{filename} get timeout lock"
    end
  end
end
