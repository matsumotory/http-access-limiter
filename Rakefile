task default: :run

desc "test"
task :test do
  sh "mruby access_limiter/access_limiter_init.rb"
end

desc "run"
task :run => [:build] do
  sh "docker run -t takumakume:mruby"
end

desc "build"
task :build do
  sh "docker build -t takumakume:mruby ."
end

task :dev => [:build] do
  sh "docker run -v `pwd`:/tmp -it takumakume:mruby /bin/bash"
end
