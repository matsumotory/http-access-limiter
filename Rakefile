task default: :run

desc "run mruby container for unit test"
task :run => [:build] do
  sh "docker run --name mruby --rm -it access_limiter:mruby"
end

desc "build mruby container for unit test"
task :build do
  sh "docker build -t access_limiter:mruby ."
end

desc "run unit test from mruby container"
task :test do
  sh "mruby access_limiter/access_limiter_init.rb"
end

desc "run mruby container for development"
task :dev => [:build] do
  sh "docker run -v `pwd`:/tmp -it access_limiter:mruby /bin/bash"
end

namespace :e2e do

  desc "run e2e test"
  task :test do
    sh "docker-compose build && docker-compose down && docker-compose up -d && /bin/bash e2e_test/test.sh"
  end

  desc "shutdown e2e test containers"
  task :clean do
    sh "docker-compose down || docker-compose rm -f"
  end

  desc "delete e2e test container images"
  task :delete => [:clean] do
    sh "docker rmi -f $(docker images -q httpaccesslimiter_apache)   > /dev/null 2>&1 || true"
    sh "docker rmi -f $(docker images -q httpaccesslimiter_abmruby)  > /dev/null 2>&1 || true"
  end

end
