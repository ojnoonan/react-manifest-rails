require "bundler/setup"
require "bundler/gem_tasks"

task default: :spec

desc "Run RSpec tests"
task :spec do
  exec "rspec"
end

desc "Run linter"
task :lint do
  exec "rubocop"
end
