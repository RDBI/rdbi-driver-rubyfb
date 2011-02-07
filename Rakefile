require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'rdbi-driver-rubyfb'
  s.version = "0.0.9"
  s.date = "2011-02-06"
  s.summary = "Firebird driver for RDBI"
  s.description = <<__eodesc
An RDBI driver for the Firebird database using Rubyfb bindings.
__eodesc
  s.platform = Gem::Platform::RUBY
  s.authors = ["Mike Pomraning"]
  s.email = "mjp@pilcrow.madison.wi.us"
  s.homepage = "http://github.com/pilcrow/rdbi-driver-rubyfb"
  s.requirements << 'rdbi' << 'rubyfb'
  s.add_dependency "rdbi", "~> 0.9"
  s.add_dependency "rubyfb", "~> 0.5.6"

  s.add_development_dependency "test/unit"
  s.add_development_dependency "rdbi-dbrc"

  s.files = Dir.glob('lib/**/*')
end

desc "Run package tests"
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

desc "Build gem"
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = false
  pkg.need_tar = false
end
