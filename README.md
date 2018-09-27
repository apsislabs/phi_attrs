# PhiAttrs

[![Gem Version](https://badge.fury.io/rb/phi_attrs.svg)](https://badge.fury.io/rb/phi_attrs) [![Build Status](https://travis-ci.org/apsislabs/phi_attrs.svg?branch=master)](https://travis-ci.org/apsislabs/phi_attrs)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'phi_attrs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install phi_attrs

## Usage

```ruby
class PatientInfo < ActiveRecord::Base
  phi_model

  exclude_from_phi :last_name
  include_in_phi :birthday

  def birthday
    Time.current
  end
end
```

Access is granted on a model level:

```ruby
info = PatientInfo.new
info.allow_phi!("allowed_user@example.com", "Customer Service")
```

or a class:

```ruby
PatientInfo.allow_phi!("allowed_user@example.com", "Customer Service")
```

As of version `0.1.5`, a block syntax is available. As above, this is available on both class and instance levels. 

Note the lack of a `!` at the end—these methods don't necessarily get along well with the mutating (bang) methods!

```ruby
PatientInfo.allow_phi('allowed_user@example.com', 'Display Customer Data') do
  @data = PatientInfo.find(params[:id]).to_json
end # Access no longer allowed beyond this point
```

### Extending PHI Access

Sometimes you'll have a single mental model that is composed of several `ActiveRecord` models joined by association. In this case, instead of calling `allow_phi!` on all joined models, we expose a shorthand of extending PHI access to related models.

```ruby
class PatientInfo < ActiveRecord::Base
  phi_model
end

class Patient < ActiveRecord::Base
  has_one :patient_info

  phi_model

  extend_phi_access :patient_info
end

patient = Patient.new
patient.allow_phi!('user@example.com', 'reason')
patient.patient_info.first_name
```

**NOTE:** This is not intended to be used on all relationships! Only those where you intend to grant implicit access based on access to another model. In this use case, we assume that allowed access to `Patient` implies allowed access to `PatientInfo`, and therefore does not require an additional `allow_phi!` check. There are no guaranteed safeguards against circular `extend_phi_access` calls!

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Docker

-   `docker-compose up`
-   `bin/ssh_to_container`

## Testing

    $ bundle exec appraisal rspec spec/phi_attrs_spec.rb

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wkirby/phi_attrs.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
