#!/bin/bash

# reset modmruby error_log
docker exec -t modmruby rm -f /var/log/httpd/error_log
docker exec -t modmruby /etc/init.d/httpd restart

echo "#"
echo "# test case 0 (performance test, pure httpd)"
echo "# ab-mruby -m test/case_0/ab-mruby.conf.rb -M test/case_0/ab-mruby.test.rb http://apache/phpinfo.php"
echo "#"
until `docker exec -t abmruby curl -s http://apache/health_check.html -o /dev/null`
do
  >&2 echo "pooling http..."
  sleep 1
done
docker exec -t abmruby ab-mruby -m test/case_0/ab-mruby.conf.rb -M test/case_0/ab-mruby.test.rb http://apache/phpinfo.php

echo "#"
echo "# test case 1-1 (performance test, enable mod_mruby & access_limiter, exists limit config)"
echo "# ab-mruby -m test/case_1/ab-mruby.conf.rb -M test/case_1/ab-mruby.test.rb http://modmruby/phpinfo.php"
echo "#"
until `docker exec -t abmruby curl -s http://modmruby/health_check.html -o /dev/null`
do
  >&2 echo "pooling http..."
  sleep 1
done
docker exec -t abmruby ab-mruby -m test/case_1/ab-mruby.conf.rb -M test/case_1/ab-mruby.test.rb http://modmruby/phpinfo.php

echo "#"
echo "# test case 1-2 (performance test, enable mod_mruby & access_limiter, not exists limit config)"
echo "# ab-mruby -m test/case_1/ab-mruby.conf.rb -M test/case_1/ab-mruby.test.rb http://modmruby/phpinfo_through_limit.php"
echo "#"
until `docker exec -t abmruby curl -s http://modmruby/health_check.html -o /dev/null`
do
  >&2 echo "pooling http..."
  sleep 1
done
docker exec -t abmruby ab-mruby -m test/case_1/ab-mruby.conf.rb -M test/case_1/ab-mruby.test.rb http://modmruby/phpinfo_through_limit.php

echo ""
echo "#"
echo "# test case 2 (status code test, enable mod_mruby & access_limiter & max_clients=1)"
echo "# ab-mruby -m test/case_2/ab-mruby.conf.rb -M test/case_2/ab-mruby.test.rb http://modmruby/phpinfo_sleep5.php"
echo "#"
docker exec -t abmruby ab-mruby -m test/case_2/ab-mruby.conf.rb -M test/case_2/ab-mruby.test.rb http://modmruby/phpinfo_sleep5.php

echo ""
echo "#"
echo "# test case 3 (race condition test)"
echo "#"
increment_log_num=`docker exec modmruby grep "increment.*phpinfo.php " /var/log/httpd/error_log | wc -l`
decrement_log_num=`docker exec modmruby grep "decrement.*phpinfo.php " /var/log/httpd/error_log | wc -l`

echo "increment_log_num      : ${increment_log_num}"
echo "decrement_log_num      : ${decrement_log_num}"
echo ""

if [ ${increment_log_num} -eq ${decrement_log_num} ] && [ ${increment_log_num} -eq 100000 ]; then
  echo "test suites: [true]"
else
  echo "test suites: [false]"
fi

echo ">>> test complete <<<"
