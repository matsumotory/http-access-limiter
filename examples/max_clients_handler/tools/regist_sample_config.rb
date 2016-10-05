#!mruby

data = [
  {
    "key"   => "/var/www/html/phpinfo.php",
    "value" => '{
      "max_clients" : 9999999,
      "time_slots" : [
      ]
    }'
  },
  {
    "key"   => "/var/www/html/phpinfo_sleep_5.php",
    "value" => '{
      "max_clients" : 2,
      "time_slots" : [
      ]
    }'
  },
  {
    "key"   => "/var/www/html/phpinfo_timeslots.php",
    "value" => '{
      "max_clients" : 9999999,
      "time_slots" : [
        { "begin" : 0, "end" : 1 },
        { "begin" : 2, "end" : 2359 }
      ]
    }'
  },
]

config_store = "/access_limiter/max_clients_handler.lmc"

if File.exist?(config_store)
  File.delete(config_store)
end

c = Cache.new :filename => config_store

data.each do |d|
  c.set(d["key"], d["value"]);
end

c.close

