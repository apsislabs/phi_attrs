# PhiAttrs

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
info = new PatientInfo
info.allow_phi!("allowed_user@example.com", "Customer Service")
```

or a class:
```ruby
PatientInfo.allow_phi!("allowed_user@example.com", "Customer Service")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Docker

* `docker-compose up`
* `bin/ssh_to_container`
* `bin/setup`

## Testing

    $ bundle exec appraisal rspec spec/phi_attrs_spec.rb

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wkirby/phi_attrs.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
