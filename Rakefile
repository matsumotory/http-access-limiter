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

