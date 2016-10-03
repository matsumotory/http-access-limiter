FROM centos:6

RUN yum install -y \
  httpd \
  httpd-devel \
  gcc \
  make \
  git \
  openssl-devel \
  readline-devel \
  ca-certificates \
  curl \
  bison

RUN git clone https://github.com/rbenv/rbenv.git /root/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git /root/.rbenv/plugins/ruby-build
RUN /root/.rbenv/plugins/ruby-build/install.sh
ENV PATH /root/.rbenv/bin:$PATH
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
ENV CONFIGURE_OPTS --disable-install-doc
ADD ./misc/ab_mruby/ruby_version /root/ruby_version
RUN xargs -L 1 rbenv install < /root/ruby_version
RUN xargs -L 1 rbenv global < /root/ruby_version
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
