require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'factory_bot_rails'
require 'faker'
require 'phi_attrs'

Bundler.require :default, :development
Combustion.initialize! :all
require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.after(:each) do
    RequestStore.end!
    RequestStore.clear!
  end

  # So we don't have to prefix everything with `FactoryBot.`
  config.include FactoryBot::Syntax::Methods
end
