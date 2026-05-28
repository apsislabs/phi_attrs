# frozen_string_literal: true

require "rubygems"
require "bundler/setup"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rake"

namespace :dummy do
  require_relative "spec/dummy/application"
  Dummy::Application.load_tasks
end

RSpec::Core::RakeTask.new(:spec)
Rake::Task[:spec].enhance(["dummy:db:create", "dummy:db:migrate"])

begin
  require "standard/rake"
rescue LoadError
  # Standard not available
end

task default: [:standard, :spec]
