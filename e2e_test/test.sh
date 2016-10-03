#!/bin/bash

function show_mem_sumally(){
  echo ""
  echo "# httpd memory size before ab test"
  docker exec -t apache cat /var/tmp/ps_before | awk '{ sz+=$5; rss+=$6 }END{ print "VmSize: "sz, "\n", "VmRss: "rss}'
  echo "# httpd memory size after ab test"
  docker exec -t apache cat /var/tmp/ps_after  | awk '{ sz+=$5; rss+=$6 }END{ print "VmSize: "sz, "\n", "VmRss: "rss}'
}

#
# performance test (pure httpd)
#

echo ""
echo ">>>"
echo ">>> performance test (pure httpd)"
echo ">>>"

docker exec -t apache mv -f /etc/httpd/conf.d/access_limiter_apache.conf /etc/httpd/conf.d/access_limiter_apache.conf_moved
docker exec -t apache /etc/init.d/httpd restart >/dev/null 2>&1

until `docker exec -t abmruby curl -s http://apache/health_check.html -o /dev/null`; do >&2 echo -n "."; sleep 1; done
docker exec -t apache bash -c 'ps aux | grep httpd > /var/tmp/ps_before'
docker exec -t abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo.php
docker exec -t apache bash -c 'ps aux | grep httpd > /var/tmp/ps_after'
show_mem_sumally

#
# performance test (httpd + mod_mruby + access_limiter)
#

echo ""
echo ">>>"
echo ">>> performance test (httpd + mod_mruby + access_limiter)"
echo ">>>"

docker exec -t apache mv -f /etc/httpd/conf.d/access_limiter_apache.conf_moved /etc/httpd/conf.d/access_limiter_apache.conf
docker exec -t apache sed -i 's/^threshold =.*/threshold = 9999999/g' /etc/httpd/conf.d/access_limiter/access_limiter.rb
docker restart apache >/dev/null 2>&1

until `docker exec -t abmruby curl -s http://apache/health_check.html -o /dev/null`; do >&2 echo -n "."; sleep 1; done
docker exec -t apache bash -c 'ps aux | grep httpd > /var/tmp/ps_before'
docker exec -t abmruby ab-mruby -m e2e_test/test_case/performance_test_config.rb -M e2e_test/test_case/performance_test_suite.rb http://apache/phpinfo.php
docker exec -t apache bash -c 'ps aux | grep httpd > /var/tmp/ps_after'
show_mem_sumally

#
# race condition test (httpd + mod_mruby + access_limiter)
#

echo ""
echo ">>>"
echo ">>> race condition test (httpd + mod_mruby + access_limiter)"
echo ">>>"

increment_log_num=`docker exec apache grep "increment:.*phpinfo.php " /var/log/httpd/error_log | wc -l`
decrement_log_num=`docker exec apache grep "decrement:.*phpinfo.php " /var/log/httpd/error_log | wc -l`

echo "increment_log_num      : ${increment_log_num}"
echo "decrement_log_num      : ${decrement_log_num}"
echo ""

if [ ${increment_log_num} -eq ${decrement_log_num} ] && [ ${increment_log_num} -eq 100000 ]; then
  echo "test suites: [true]"
else
  echo "test suites: [false]"
fi

echo ""
echo ">>>"
echo ">>> reach limit test (httpd + mod_mruby + access_limiter)"
echo ">>>"

docker exec -t apache sed -i 's/^threshold =.*/threshold = 2/g' /etc/httpd/conf.d/access_limiter/access_limiter.rb
docker restart apache >/dev/null 2>&1

until `docker exec -t abmruby curl -s http://apache/health_check.html -o /dev/null`; do >&2 echo -n "."; sleep 1; done
docker exec -t abmruby ab-mruby -m e2e_test/test_case/reach_limit_test_config.rb -M e2e_test/test_case/reach_limit_test_suite.rb http://apache/phpinfo_sleep_5.php

