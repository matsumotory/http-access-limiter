FROM centos:latest

RUN yum install -y \
  gcc \
  git \
  openssl-devel \
  ca-certificates \
  rubygems \
  curl \
  bison

RUN gem install \
  mgem \
  rake

RUN git clone https://github.com/mruby/mruby.git
ADD misc/mruby/build_config.rb mruby/
RUN cd mruby && rake
RUN cp mruby/bin/mruby /usr/local/bin
RUN mkdir -p /access_limiter

ADD . /tmp
WORKDIR /tmp

CMD rake test
