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
RUN git clone --recursive https://github.com/matsumoto-r/ab-mruby.git
WORKDIR /usr/local/src/ab-mruby/
RUN make
RUN cp -p ab-mruby /usr/local/bin/

ADD . /tmp
WORKDIR /tmp

CMD /sbin/init
