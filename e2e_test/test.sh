#!/bin/bash

function echo_test_title(){
  echo ""
  echo ">>"
  echo ">> $1"
  echo ">>"
}

function init(){
  docker exec apache bash -c 'echo -n "" > /var/log/httpd/error_log'
  docker restart apache >/dev/null 2>&1
  until `docker exec abmruby curl -s http://apache/health_check.html -o /dev/null`; do >&2 echo "pooling http..."; sleep 2; done
}

function get_ps_before(){
  docker exec apache bash -c 'ps aux > /var/tmp/ps_before'
}

function get_ps_after(){
  docker exec apache bash -c 'ps aux > /var/tmp/ps_after'
}

function show_httpd_mem_sumally(){
  echo ""
  echo "# httpd memory size before ab test"
  docker exec apache grep httpd /var/tmp/ps_before | awk '{ sz+=$5; rss+=$6 }END{ print "VmSize: "sz, "\n", "VmRss: "rss}'
  echo "# httpd memory size after ab test"
  docker exec apache grep httpd /var/tmp/ps_after  | awk '{ sz+=$5; rss+=$6 }END{ print "VmSize: "sz, "\n", "VmRss: "rss}'
}

function race_condition_test(){
  file=$1
  increment_log_num=`docker exec apache grep "increment:.*${file} " /var/log/httpd/error_log | wc -l`
  decrement_log_num=`docker exec apache grep "decrement:.*${file} " /var/log/httpd/error_log | wc -l`

  echo "increment_log_num      : ${increment_log_num}"
  echo "decrement_log_num      : ${decrement_log_num}"
  echo ""

  if [ ${increment_log_num} -eq ${decrement_log_num} ] && [ ${increment_log_num} -eq 100000 ]; then
    echo "test suites: [true]"
  else
    echo "test suites: [false]"
  fi
}

# ------------------------------------------------------------------------------
# pure httpd
# ------------------------------------------------------------------------------

#
# performance test (pure httpd)
#

echo_test_title "performance test (pure httpd)"
init
get_ps_before
docker exec abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo.php
get_ps_after
show_httpd_mem_sumally

# ------------------------------------------------------------------------------
# httpd + mod_mruby + access_limiter
# ------------------------------------------------------------------------------

docker exec apache mv /etc/httpd/conf.d/access_limiter/access_limiter_apache.conf /etc/httpd/conf.d/

#
# performance test (httpd + mod_mruby + access_limiter)
#

echo_test_title "performance test (httpd + mod_mruby + access_limiter)"
docker exec apache sed -i 's/^threshold =.*/threshold = 9999999/g' /etc/httpd/conf.d/access_limiter/access_limiter.rb
init
get_ps_before
docker exec abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo.php
get_ps_after
show_httpd_mem_sumally

#
# race condition test (httpd + mod_mruby + access_limiter)
#

echo_test_title "race condition test (httpd + mod_mruby + access_limiter)"
race_condition_test "phpinfo.php"

#
# reach limit test (httpd + mod_mruby + access_limiter)
#

echo_test_title "reach limit test (httpd + mod_mruby + access_limiter)"
docker exec apache sed -i 's/^threshold =.*/threshold = 2/g' /etc/httpd/conf.d/access_limiter/access_limiter.rb
init
docker exec abmruby ab-mruby -m e2e_test/test_case/reach_limit_test_config.rb -M e2e_test/test_case/reach_limit_test_suite.rb http://apache/phpinfo_sleep_5.php

# ------------------------------------------------------------------------------
# httpd + mod_mruby + access_limiter max_clients_handler
# ------------------------------------------------------------------------------

docker exec apache mv /etc/httpd/conf.d/access_limiter_apache.conf /etc/httpd/conf.d/access_limiter/
docker exec apache mv /etc/httpd/conf.d/access_limiter/access_limiter_apache_max_clients_handler.conf /etc/httpd/conf.d/

docker exec apache mruby /etc/httpd/conf.d/access_limiter/regist_sample_config.rb
docker exec apache chown apache:apache /access_limiter/max_clients_handler.lmc

#
# performance test (httpd + mod_mruby + access_limiter + max_clients_handler(empty config))
#

echo_test_title "performance test (httpd + mod_mruby + access_limiter + max_clients_handler(empty config))"
init
get_ps_before
docker exec abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo_unlimited.php
get_ps_after
show_httpd_mem_sumally

#
# performance test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config))
#

echo_test_title "performance test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config))"
init
get_ps_before
docker exec abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo.php
get_ps_after
show_httpd_mem_sumally

#
# race condition test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config))
#

echo_test_title "race condition test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config))"
race_condition_test "phpinfo.php"

#
# performance test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config and enable timeslots))
#

echo_test_title "performance test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config and enable timeslots))"
init
get_ps_before
docker exec abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo_timeslots.php
get_ps_after
show_httpd_mem_sumally

#
# race condition test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config and enable timeslots))
#

echo_test_title "race condition test (httpd + mod_mruby + access_limiter + max_clients_handler(exist config and enable timeslots))"
race_condition_test "phpinfo_timeslots.php"

#
# reach limit test (httpd + mod_mruby + access_limiter + max_clients_handler)
#

echo_test_title "reach limit test (httpd + mod_mruby + access_limiter + max_clients_handler)"
init
docker exec abmruby ab-mruby -m e2e_test/test_case/reach_limit_test_config.rb -M e2e_test/test_case/reach_limit_test_suite.rb http://apache/phpinfo_sleep_5.php

