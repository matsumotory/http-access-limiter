FROM centos:6

RUN yum install -y \
  httpd \
  httpd-devel \
  php \
  gcc \
  make \
  git \
  openssl-devel \
  readline-devel \
  ca-certificates \
  curl \
  bison

RUN git clone https://github.com/sstephenson/rbenv.git /root/.rbenv
RUN git clone https://github.com/sstephenson/ruby-build.git /root/.rbenv/plugins/ruby-build
RUN /root/.rbenv/plugins/ruby-build/install.sh
ENV PATH /root/.rbenv/bin:$PATH
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
ENV CONFIGURE_OPTS --disable-install-doc
ADD ./misc/mod_mruby/ruby_version /root/ruby_version
RUN xargs -L 1 rbenv install < /root/ruby_version
RUN xargs -L 1 rbenv global < /root/ruby_version
ENV PATH /root/.rbenv/shims:$PATH

RUN rbenv exec gem install rake

WORKDIR /usr/local/src/
RUN git clone https://github.com/matsumoto-r/mod_mruby.git

WORKDIR /usr/local/src/mod_mruby/
ADD misc/mod_mruby/build_config.rb .
RUN sh build.sh
RUN cp -pf src/.libs/mod_mruby.so /usr/lib64/httpd/modules/mod_mruby.so
RUN cp -pf /usr/local/src/mod_mruby/mruby/bin/mruby /usr/local/bin/

RUN mkdir /etc/httpd/conf.d/access_limiter
COPY access_limiter_apache.conf /etc/httpd/conf.d/access_limiter/
COPY access_limiter/* /etc/httpd/conf.d/access_limiter/

# max_clients_handler files
RUN mkdir -p /access_limiter
COPY examples/max_clients_handler/* /etc/httpd/conf.d/access_limiter/
COPY examples/max_clients_handler/access_limiter/* /etc/httpd/conf.d/access_limiter/
COPY examples/max_clients_handler/tools/* /etc/httpd/conf.d/access_limiter/

RUN sed -i 's/^LogLevel.*/LogLevel debug/' /etc/httpd/conf/httpd.conf
RUN sed -i 's/;date.timezone =/date.timezone = Asia\/Tokyo/g' /etc/php.ini

RUN echo 'OK'                             > /var/www/html/health_check.html
RUN echo '<?php phpinfo(); ?>'            > /var/www/html/phpinfo.php
RUN echo '<?php phpinfo(); ?>'            > /var/www/html/phpinfo_timeslots.php
RUN echo '<?php phpinfo(); ?>'            > /var/www/html/phpinfo_unlimited.php
RUN echo '<?php sleep(5); phpinfo(); ?>'  > /var/www/html/phpinfo_sleep_5.php

RUN chkconfig httpd on

ADD . /tmp
WORKDIR /tmp

CMD /sbin/init
