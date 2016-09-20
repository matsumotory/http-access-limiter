# httpd error_log
log_file="/var/log/httpd/error_log"

# log search pattern (destination file for race condition test)
# ext: /var/www/html/phpinfo.php
log_pat=$1

if [ ! -f ${log_file} ]; then
  echo "check_race_condition.sh: error: ${log_file} is not found."
  exit 1
fi

cnt_inc=`grep ""`

