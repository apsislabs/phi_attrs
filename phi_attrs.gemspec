# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "phi_attrs/version"

Gem::Specification.new do |spec|
  spec.name = "phi_attrs"
  spec.version = PhiAttrs::VERSION
  spec.authors = ["Wyatt Kirby"]
  spec.email = ["wyatt@apsis.io"]

  spec.summary = "PHI Access Restriction & Logging for Rails ActiveRecord"
  spec.homepage = "https://www.apsis.io"
  spec.license = "MIT"
  spec.post_install_message = '
    Thank you for installing phi_attrs! By installing this gem,
    you acknowledge and agree to the disclaimer as provided in the
    DISCLAIMER.txt file.

    For full details, see: https://github.com/apsislabs/phi_attrs/blob/main/DISCLAIMER.txt
  '

  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir["{app,config,lib}/**/*", "CHANGELOG.md", "DISCLAIMER.txt", "LICENSE.txt", "README.md"]

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "benchmark"
  spec.add_dependency "rails", ">= 7.0.0", "< 9.0"
  spec.add_dependency "request_store", "~> 1.4"

  spec.add_development_dependency "appraisal", "~> 2.5"
  spec.add_development_dependency "bump"
  spec.add_development_dependency "bundler", ">= 2.4"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "factory_bot_rails"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "rake", "~> 13.3"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "standardrb"
  spec.add_development_dependency "tzinfo-data"
  spec.metadata["rubygems_mfa_required"] = "false"
end
