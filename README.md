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

# Also add config into access_limiter_end.rb
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
      current = limit.current
      Server.errlogger Server::LOG_INFO, "access_limiter: increment: file:#{file} counter:#{current}"
      if current > threshold
        Server.errlogger Server::LOG_INFO, "access_limiter: file:#{file} reached threshold: #{threshold}: return #{Server::HTTP_SERVICE_UNAVAILABLE}"
        Server.return Server::HTTP_SERVICE_UNAVAILABLE
      end
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
  if timeout
    Server.errlogger Server::LOG_INFO, "access_limiter: get timeout lock, #{file}"
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
      Server.errlogger Server::LOG_INFO, "access_limiter_end: decrement: file:#{file} counter:#{limit.current}"
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
end
```

### flexible programmable configuration per target file of DDoS

##### Features added to access_limiter

- The number of max clients per target file.
- A few time slots to enable access_limiter.
- Done without having to reload these settings, because store the settings to localmemcache.
  - For example (limit on par file)
    - key

      ```
      /path/to/example.php
      ```

    - value

      ```json
      {
        "max_clients" : 30,
        "time_slots" : [
          { "begin" : 1100, "end" : 1200 },
          { "begin" : 2200, "end" : 2300 }
        ]
      }
      ```

##### Code (For example: limit on per file)

- access_limiter.rb

```ruby
Server = get_server_class
r = Server::Request.new
cache = Userdata.new.shared_cache
global_mutex = Userdata.new.shared_mutex

# max_clients_handler config store
config_store = Userdata.new.shared_config_store

file = r.filename

# Also add config into access_limiter_end.rb
config = {
  # access limmiter by target
  :target => file,
}

limit = AccessLimiter.new r, cache, config
max_clients_handler = MaxClientsHandler.new(
  limit,
  config_store
)

if max_clients_handler.config
  # process-shared lock
  timeout = global_mutex.try_lock_loop(50000) do
    begin
      Server.errlogger Server::LOG_INFO, "access_limiter: cleanup_counter: file:#{file}" if limit.cleanup_counter
      limit.increment
      current = limit.current
      Server.errlogger Server::LOG_INFO, "access_limiter: increment: file:#{file} counter:#{current}"
      if max_clients_handler.limit?
        Server.errlogger Server::LOG_INFO, "access_limiter: file:#{file} reached threshold: #{max_clients_handler.max_clients}: return #{Server::HTTP_SERVICE_UNAVAILABLE}"
        Server.return Server::HTTP_SERVICE_UNAVAILABLE
      end
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
  if timeout
    Server.errlogger Server::LOG_INFO, "access_limiter: get timeout lock, #{file}"
  end
end
```

- access_limiter_end.rb

```ruby
Server = get_server_class
r = Server::Request.new
cache = Userdata.new.shared_cache
global_mutex = Userdata.new.shared_mutex

# max_clients_handler config store
config_store = Userdata.new.shared_config_store

file = r.filename

config = {
  # access limmiter by target
  :target => file,
}

limit = AccessLimiter.new r, cache, config
max_clients_handler = MaxClientsHandler.new(
  limit,
  config_store
)
if max_clients_handler.config
  # process-shared lock
  global_mutex.try_lock_loop(50000) do
    begin
      limit.decrement
      Server.errlogger Server::LOG_INFO, "access_limiter_end: decrement: file:#{file} counter:#{limit.current}"
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
end
```

## Unit Test

```
rake
```

```
# Running tests:
...
Finished tests in 0.003936s, 762.1951 tests/s, 3556.9106 assertions/s.
3 tests, 14 assertions, 0 failures, 0 errors, 0 skips
```

## E2E Test

- The purpose
  - Performance degradation before and after renovation.
  - Performance degradation of each operation pattern.
  - Check memory leak.
  - Check race condition.
  - Check response code when reach max clients.

```
rake e2e:test
```

```
>>
>> performance test (pure httpd)
>>
 :
Finished 100000 requests
[TEST CASE] [true] CompleteRequests (100000) should be 100000
[TEST CASE] [true] RequestPerSecond (1108.7446066227) should be over 1
[TEST CASE] [true] Non2xxResponses (0) should be 0

test suites: [true]

# httpd memory size before ab test
VmSize: 2114748
 VmRss: 65456
# httpd memory size after ab test
VmSize: 28284224
 VmRss: 1376520
 :
 :
```

## depend mrbgem
```ruby
  conf.gem :github => 'matsumoto-r/mruby-localmemcache'
  conf.gem :github => 'matsumoto-r/mruby-mutex'
  # use MaxClientsHandler
  conf.gem :github => 'iij/mruby-iijson' or 'mattn/mruby-json'
```

http-access-limiter has the counter of any key in process-shared memory. When Apache or nginx was restarted, the counter was freed.

## License
under the MIT License:
- see LICENSE file

