config = {:namespace =>"aceess_limiter"}

c = Cache.new config
c.clear

Userdata.new.shared_cache = c
