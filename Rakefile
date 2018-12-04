# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# Set Chandler options
Chandler::Tasks.configure do |config|
  config.changelog_path = 'CHANGELOG.md'
  config.github_repository = 'apsislabs/phi_attrs'
end

# Add chandler as a prerequisite for `rake release`
task 'release:rubygem_push' => 'chandler:push'

task default: :spec
