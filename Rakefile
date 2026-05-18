require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/stress/**/*_test.rb")
  t.verbose = true
end

Rake::TestTask.new("test:stress") do |t|
  t.libs << "test"
  t.test_files = FileList["test/stress/**/*_test.rb"]
  t.verbose = true
end

task default: :test

desc "Run linter"
task :lint do
  exec "rubocop"
end
