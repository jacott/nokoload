require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "nokoload"
    s.summary = "A Web load testing tool"
    s.description = "Nokoload is a Web load testing tool. It is built on top of net/http and nokogiri.

Nokoload has a DSL which allows running mulitple processes against a web location. Statistics are collected and can be
written to a csv file for displaying results. Fields can be refered to via their labels."
    s.email = "geoffjacobsen@gmail.com"
    s.authors = ["Geoff Jacobsen"]
    s.files =Dir.glob("{lib,test}/**/*")
    s.add_dependency 'nokogiri', '>= 1.4.0'
s
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << "." << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Nokoload #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
