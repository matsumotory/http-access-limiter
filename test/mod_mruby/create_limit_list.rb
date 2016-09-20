c = Cache.new :filename => "/access_limiter/limit_list.lmc"

c.set(
  "/var/www/html/phpinfo.php",
  '{
    "max_clients" : 99999999,
    "time_slots" : [
    ]
  }'
)

c.set(
  "/var/www/html/phpinfo_sleep5.php",
  '{
    "max_clients" : 1,
    "time_slots" : [
    ]
  }'
)

c.close
