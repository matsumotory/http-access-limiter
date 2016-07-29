# http-access-limiter

Count the number of references to the requested file on Apache and Nginx using mruby code.

http-access-limiter use same Ruby code between Apache(mod_mruby) and nginx(ngx_mruby).

## Install and Configuration
- install [mod_mruby](https://github.com/matsumoto-r/mod_mruby) if you use apache
- install [ngx_mruby](https://github.com/matsumoto-r/ngx_mruby) if you use nginx

### Apache and mod_mruby
- copy `access_limiter/` and `access_limiter_apache.conf` into `/etc/httpd/conf.d/`
```apache
LoadModule mruby_module modules/mod_mruby.so

<IfModule mod_mruby.c>
  mrubyPostConfigMiddle         /etc/httpd/conf.d/access_limiter/access_limiter_init.rb cache
  mrubyChildInitMiddle          /etc/httpd/conf.d/access_limiter/access_limiter_worker_init.rb cache
  <FilesMatch ^.*\.php$>
    mrubyAccessCheckerMiddle      /etc/httpd/conf.d/access_limiter/access_limiter.rb cache
    mrubyLogTransactionMiddle     /etc/httpd/conf.d/access_limiter/access_limiter_end.rb cache
  </FilesMatch>
</IfModule>
```

### nginx and ngx_mruby
- copy `access_limiter/` into `/path/to/nginx/conf.d/`
- write configuration like `access_limiter_nginx.conf`
```nginx
# exmaple

http {
  mruby_init /path/to/nginx/conf/access_limiter/access_limiter_init.rb cache;
  mruby_init_worker /path/to/nginx/conf/access_limiter/access_limiter_worker_init.rb cache;
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
  limit = AccessLimiter.new r, cache, config
  # process-shared lock
  timeout = global_mutex.try_lock_loop(50000) do
    begin
      limit.increment
      Server.errlogger Server::LOG_NOTICE, "access_limiter: file:#{r.filename} counter:#{limit.current}"
      if limit.current > threshold
        Server.errlogger Server::LOG_NOTICE, "access_limiter: file:#{r.filename} reached threshold: #{threshold}: return #{Server::HTTP_SERVICE_UNAVAILABLE}"
        Server.return Server::HTTP_SERVICE_UNAVAILABLE
      end
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
  if timeout
    Server.errlogger Server::LOG_NOTICE, "access_limiter: get timeout lock, #{r.filename}"
  end
end
```

- `access_limiter_end.rb`

```ruby
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
  limit = AccessLimiter.new r, cache, config
  # process-shared lock
  global_mutex.try_lock_loop(50000) do
    begin
      limit.decrement
      Server.errlogger Server::LOG_NOTICE, "access_limiter_end: #{r.filename} #{limit.current}"
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
end
```

## depend mrbgem
```ruby
  conf.gem :github => 'matsumoto-r/mruby-localmemcache'
  conf.gem :github => 'matsumoto-r/mruby-mutex'
```

http-access-limiter has the counter of any key in process-shared memory. When Apache or nginx was restarted, the counter was freed.

## License
under the MIT License:
- see LICENSE file

