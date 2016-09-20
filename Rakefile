task default: :run

desc "test"
task :test do
  sh "mruby access_limiter/access_limiter_init.rb"
end

desc "run"
task :run => [:build] do
  sh "docker run --name mruby --rm -it access_limiter:mruby"
end

desc "build"
task :build do
  sh "docker build -t access_limiter:mruby ."
end

task :dev => [:build] do
  sh "docker run -v `pwd`:/tmp -it access_limiter:mruby /bin/bash"
end

task :delete do
  sh "docker rmi -f $(docker images -q access_limiter:mruby) > /dev/null 2>&1 || true"
end

namespace :e2e do
  desc "E2E test for ab-mruby"
  task :test do
    sh "/bin/bash test/test.sh"
  end

  desc "E2E run all docker and test"
  task :run => [:build, :clean] do
    sh "docker-compose up -d"
    sh "/bin/bash test/test.sh"
  end

  desc "E2E build all docker"
  task :build do
    sh "docker-compose build"
  end

  desc "E2E clean all"
  task :clean do
    sh "docker-compose down || docker-compose rm -f"
  end

  task :dev => [:build, :clean] do
    sh "docker-compose up -d"
    sh "docker ps -a | grep httpaccesslimiter"
  end

  task :dev_modmruby do
    sh "docker exec -it modmruby /bin/bash"
  end

  task :dev_abmruby do
    sh "docker exec -it abmruby /bin/bash"
  end

  task :dev_apache do
    sh "docker exec -it apache /bin/bash"
  end
end
