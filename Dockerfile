FROM centos:latest

RUN yum install -y \
  gcc \
  git \
  openssl-devel \
  rubygems \
  curl \
  bison

RUN curl http://curl.haxx.se/ca/cacert.pem -o /opt/cacert.pem
ENV SSL_CERT_FILE=/opt/cacert.pem

RUN gem install bundler
RUN gem install mgem
RUN gem install rake

RUN git clone https://github.com/mruby/mruby.git
ADD misc/build_config.rb mruby/
RUN cd mruby && rake
RUN cp mruby/bin/mruby /usr/local/bin

ADD . /tmp
WORKDIR /tmp
RUN bundle install --binstubs

CMD bin/rake test
