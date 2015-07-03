config = {:namespace =>"aceess_limitter"}

c = Cache.new config
c.clear

Userdata.new.shared_cache = c
