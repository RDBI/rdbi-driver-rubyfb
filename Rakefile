require 'rubygems'
require 'rake'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'

FILES = FileList['Rakefile', 'LICENSE', 'README.rdoc', 'lib/**/*',
                 'test/**/*']

TESTS = FileList['test/test_*.rb']

spec = Gem::Specification.new do |s|
  s.name = 'rdbi-driver-rubyfb'
  s.version = "0.0.9"
  s.date = "2011-02-20"
  s.summary = "Firebird driver for RDBI"
  s.description = <<__eodesc
An RDBI driver for the Firebird database using Rubyfb bindings.
__eodesc
  s.platform = Gem::Platform::RUBY
  s.authors = ["Mike Pomraning"]
  s.email = "mjp@pilcrow.madison.wi.us"
  s.homepage = "http://github.com/RDBI/rdbi-driver-rubyfb"
  s.requirements << 'rdbi' << 'rubyfb'
  s.add_dependency "rdbi", "~> 0.9"
  s.add_dependency "rubyfb", "~> 0.5.6"

  s.add_development_dependency "test/unit"
  s.add_development_dependency "rdbi-dbrc"

  s.files = FILES
  s.test_files = TESTS

  s.has_rdoc = true
end

desc "Generate rdoc"
Rake::RDocTask.new("rdoc") do |rdoc|
  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "RDBI::Driver::Rubyfb"
  # Show source inline with line numbers
  rdoc.options << "--inline-source" << "--line-numbers"
  # Make the readme file the start page for the generated html
  rdoc.options << '--main' << 'README'
  rdoc.rdoc_files.include('lib/**/*.rb',
                          'CHANGES',
                          'README.rdoc',
                          'LICENSE')
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

desc "Run test coverage (rcov)"
begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.test_files = TESTS
    t.libs << "test" << "lib"
    t.rcov_opts << '--exclude /gems/,/Library/,/usr/,spec,lib/tasks'
  end
rescue LoadError
  task :rcov do
    puts "Error - you seem to be missing 'rcov'"
    exit 1
  end
end

