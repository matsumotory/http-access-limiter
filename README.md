# http-access-limiter

Count the number of references to the requested file on Apache and Nginx using mruby code.

http-access-limiter use same Ruby code between Apache(mod_mruby) and nginx(ngx_mruby).

## Install and Configuration
- install [mod_mruby](https://github.com/matsumoto-r/mod_mruby) if you use apache
- install [ngx_mruby](https://github.com/matsumoto-r/ngx_mruby) if you use nginx

### Apache and mod_mruby
- copy `access_limiter/` and `access_limiter_apache.conf` into `/etc/httpd/conf.d/`
- mkdir /access_limiter
```apache
LoadModule mruby_module modules/mod_mruby.so

<IfModule mod_mruby.c>
  mrubyPostConfigMiddle         /etc/httpd/conf.d/access_limiter/access_limiter_init.rb cache
  <FilesMatch ^.*\.php$>
    mrubyAccessCheckerMiddle      /etc/httpd/conf.d/access_limiter/access_limiter.rb cache
    mrubyLogTransactionMiddle     /etc/httpd/conf.d/access_limiter/access_limiter_end.rb cache
  </FilesMatch>
</IfModule>
```

### nginx and ngx_mruby
- copy `access_limiter/` into `/path/to/nginx/conf.d/`
- write configuration like `access_limiter_nginx.conf`
- mkdir /access_limiter
```nginx
# exmaple

http {
  mruby_init /path/to/nginx/conf/access_limiter/access_limiter_init.rb cache;
  server {
    location ~ \.php$ {
      mruby_access_handler /path/to/nginx/conf/access_limiter/access_limiter.rb cache;
      mruby_log_handler /path/to/nginx/conf/access_limiter/access_limiter_end.rb cache;
    }
}
```
### programmable configuration of DoS
- `access_limiter.rb`
```ruby
Server = get_server_class
request = Server::Request.new

unless request.sub_request?
  global_mutex = Userdata.new.shared_mutex

  config = {
    :target => request.filename,
  }

  al = AccessLimiter.new(config)

  if al.key_exist?
    timeout = global_mutex.try_lock_loop(50000) do
      begin
        al.increment
        Server.errlogger Server::LOG_DEBUG, "access_limiter: increment: file: #{request.filename} counter: #{al.current} max_clients: #{al.max_clients} time_slot: #{al.time_slot}"
        if al.limit?
          Server.errlogger Server::LOG_NOTICE, "access_limiter: limit: file: #{request.filename} return: 503"
          Server.return Server::HTTP_SERVICE_UNAVAILABLE
        end
      rescue => e
        raise "access_limiter: failed: #{e}"
      ensure
        global_mutex.unlock
      end
    end
    if timeout
      Server.errlogger Server::LOG_NOTICE, "access_limiter: failed: file: #{request.filename} get timeout lock"
    end
  end
end
```

- `access_limiter_end.rb`

```ruby
Server = get_server_class
request = Server::Request.new

unless request.sub_request?
  global_mutex = Userdata.new.shared_mutex
  config = {
    :target => request.filename,
  }

  al = AccessLimiter.new(config)

  if al.key_exist?
    global_mutex.try_lock_loop(50000) do
      begin
        al.decrement
        Server.errlogger Server::LOG_DEBUG, "access_limiter: decrement: file: #{request.filename} counter: #{al.current}"
      rescue => e
        raise "access_limiter: failed: #{e}"
      ensure
        global_mutex.unlock
      end
    end
  end
end
```

## Test

### Unit Test

```
rake
```

### E2E Test

```
rake e2e:run
```

- The difference between enable and disable access_limiter of performance
- To return a 503 error when max_clients has reached the threshold
- The race condition has not occurred

## depend mrbgem
```ruby
  conf.gem :github => 'matsumoto-r/mruby-localmemcache'
  conf.gem :github => 'matsumoto-r/mruby-mutex'
  conf.gem :github => 'iij/mrubyiijson' # or 'mattn/mruby-json'
```

http-access-limiter has the counter of any key in process-shared memory. When Apache or nginx was restarted, the counter was freed.

## License
under the MIT License:
- see LICENSE file

