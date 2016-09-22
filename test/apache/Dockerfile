FROM centos:6

RUN yum install -y \
  #curl \
  httpd \
  #httpd-devel \
  php \
  ca-certificates

RUN sed -i 's/^#ServerName.*/ServerName apache.ab.local/' /etc/httpd/conf/httpd.conf
RUN chkconfig httpd on

ADD ./test/mod_mruby /var/www/html

ADD . /tmp
WORKDIR /tmp

RUN sed -i 's/^LogLevel.*/LogLevel debug/' /etc/httpd/conf/httpd.conf
RUN /etc/init.d/httpd configtest && /etc/init.d/httpd start
CMD /sbin/init
