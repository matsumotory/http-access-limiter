FROM centos:6

RUN yum install -y \
  gcc \
  make \
  git \
  openssl-devel \
  curl \
  zlib \
  zlib-devel \
  pcre-devel \
  httpd \
  httpd-devel \
  php \
  ca-certificates \
  bison

WORKDIR /root
RUN git clone https://github.com/rbenv/rbenv.git /root/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git /root/.rbenv/plugins/ruby-build
RUN /root/.rbenv/plugins/ruby-build/install.sh
ENV PATH /root/.rbenv/bin:$PATH
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
ENV CONFIGURE_OPTS --disable-install-doc
RUN rbenv install 1.9.3-p551
RUN rbenv global 1.9.3-p551
ENV PATH /root/.rbenv/shims:$PATH

RUN rbenv exec gem install rake

WORKDIR /usr/local/src/
RUN git clone https://github.com/matsumoto-r/mod_mruby.git

WORKDIR /usr/local/src/mod_mruby/
ADD misc/mod_mruby/build_config.rb ./
RUN sh build.sh
RUN cp -pf src/.libs/mod_mruby.so /usr/lib64/httpd/modules/mod_mruby.so
RUN cp -pf /usr/local/src/mod_mruby/mruby/bin/mruby /usr/local/bin/

RUN sed -i 's/;date.timezone =/date.timezone = Asia\/Tokyo/g' /etc/php.ini
RUN sed -i 's/^#ServerName.*/ServerName modmruby.ab.local/' /etc/httpd/conf/httpd.conf
RUN sed -i 's/^LogLevel.*/LogLevel debug/' /etc/httpd/conf/httpd.conf
RUN chkconfig httpd on

ADD ./test/mod_mruby /var/www/html

RUN mkdir /access_limiter
RUN mruby /var/www/html/create_limit_list.rb
RUN chown -R apache:apache /access_limiter

ADD . /tmp
WORKDIR /tmp

RUN cp -f access_limiter_apache.conf /etc/httpd/conf.d/
RUN mkdir -p /etc/httpd/conf.d/access_limiter && cp -f access_limiter/* /etc/httpd/conf.d/access_limiter/

RUN /etc/init.d/httpd configtest && /etc/init.d/httpd start
CMD /sbin/init
