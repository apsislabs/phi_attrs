# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'phi_attrs/version'

Gem::Specification.new do |spec|
  spec.name          = 'phi_attrs'
  spec.version       = PhiAttrs::VERSION
  spec.authors       = ['Wyatt Kirby']
  spec.email         = ['wyatt@apsis.io']

  spec.summary       = 'PHI Access Restriction & Logging for Rails ActiveRecord'
  spec.homepage      = 'http://www.apsis.io'
  spec.license       = 'MIT'
  spec.post_install_message = %q`
    Thank you for installing phi_attrs! By installing this gem,
    you acknowledge and agree to the disclaimer as provided in the
    DISCLAIMER.txt file.

    For full details, see: https://github.com/apsislabs/phi_attrs/blob/master/DISCLAIMER.txt
  `

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'rails', '>= 4.2.0'
  spec.add_runtime_dependency 'request_store', '~> 1.4'

  spec.add_development_dependency 'appraisal', '~> 2.1'
  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'chandler'
  spec.add_development_dependency 'combustion', '~> 0.9.1'
  spec.add_development_dependency 'factory_bot_rails'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rspec-rails', '~> 3.7'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov', '~> 0.16'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
end
