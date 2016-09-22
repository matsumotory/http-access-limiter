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
    global_mutex.try_lock_loop(50000) do
      begin
        al.decrement
        Server.errlogger Server::LOG_DEBUG, "access_limiter: decrement: file: #{filename} counter: #{al.current}"
      rescue => e
        raise "access_limiter: failed: #{e}"
      ensure
        global_mutex.unlock
      end
    end
  end
end
