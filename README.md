# phi_attrs [![Gem Version](https://badge.fury.io/rb/phi_attrs.svg)](https://badge.fury.io/rb/phi_attrs) [![Build Status](https://travis-ci.org/apsislabs/phi_attrs.svg?branch=master)](https://travis-ci.org/apsislabs/phi_attrs)

HIPAA compliant PHI access logging for Ruby on Rails.

According to [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html) `§ 164.312(b)`, HIPAA covered entities are required to:

> Implement hardware, software, and/or procedural mechanisms that record and examine activity in information systems that contain or use electronic protected health information.

The `phi_attrs` gem is intended to assist with implementing logging to comply with the access log requirements of `§ 164.308(a)(1)(ii)(D)`:

> Information system activity review (Required). Implement procedures to regularly review records of information system activity, such as audit logs, access reports, and security incident tracking reports.

To do so, `phi_attrs` extends `ActiveRecord` models by adding automated logging and explicit access control methods. The access control mechanism creates a separate `phi_access_log`.

**Please Note:** while `phi_attrs` helps facilitate access logging, it still requires due diligence by developers, both in ensuring that models and attributes which store PHI are flagged with `phi_model` and that calls to `allow_phi!` properly attribute both a _unique_ identifier and an explicit reason for PHI access.

**Please Note:** there are other aspects of building a HIPAA secure application which are not addressed by `phi_attrs`, and as such _use of `phi_attrs` on its own does not ensure HIPAA Compliance_. For further reading on how to ensure your application meets the HIPAA security standards, review the [HHS Security Series Technical Safeguards](https://www.hhs.gov/sites/default/files/ocr/privacy/hipaa/administrative/securityrule/techsafeguards.pdf) and [Summary of the HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/laws-regulations/index.html), in addition to consulting your compliance and legal counsel.

## Stability

All versions of this project below `1.0.0` should be considered unstable beta software. Even minor-version updates may introduce breaking changes to the public API at this stage. We strongly suggest that you lock the installed version in your Gemfile to avoid unintended breaking updates.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'phi_attrs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install phi_attrs

## Initialize

Create an initializer to configure the PHI log file location.

Example:

 `config/initializers/phi_attrs.rb`

```ruby
PhiAttrs.configure do |conf|
  conf.log_path = Rails.root.join("log", "phi_access_#{Rails.env}.log")
end
```

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

Access is granted on a instance level:

```ruby
info = PatientInfo.new
info.allow_phi!("allowed_user@example.com", "Customer Service")
```

*When using on an instance if you find it in a second place you will need to call allow_phi! again.*

or a class:

```ruby
PatientInfo.allow_phi!("allowed_user@example.com", "Customer Service")
```

As of version `0.1.5`, a block syntax is available. As above, this is available on both class and instance levels.

Note the lack of a `!` at the end. These methods should not be used alongside the mutating (bang) methods! We recommend using the block syntax for tighter control.

```ruby
patient = PatientInfo.find(params[:id])
patient.allow_phi('allowed_user@example.com', 'Display Customer Data') do
  @data = patient.to_json
end # Access no longer allowed beyond this point
```

or a block on a class:

```ruby
PatientInfo.allow_phi('allowed_user@example.com', 'Display Customer Data') do
  @data = PatientInfo.find(params[:id]).to_json
end # Access no longer allowed beyond this point
```

### Controlling What Is PHI

When you include `phi_model` on your active record all fields except the id will be considered PHI.

To remove fields from PHI tracking use `exclude_from_phi`:

```ruby
# created_at and updated_at will be accessible as normal
class PatientInfo < ActiveRecord::Base
  phi_model

  exclude_from_phi :created_at, :updated_at
end
```

To add a method as PHI use `include_in_phi`. Include takes precedence over exclude so a method that appears in both will be considered PHI.

```ruby
# birthday and node will throw PHIExceptions if accessed without permission
class PatientInfo < ActiveRecord::Base
  phi_model

  include_in_phi :birthday, :note

  def birthday
    Time.current
  end

  attr_accessor :note
end
```

#### Example Usage

Example of `exclude_from_phi` and `include_in_phi` with inheritance.

```ruby
class PatientInfo < ActiveRecord::Base
  phi_model
end

pi = PatientInfo.new(first_name: "Ash", last_name: "Ketchum")
pi.created_at
# PHIAccessException!
pi.last_name
# PHIAccessException!
pi.allow_phi "Ash", "Testing PHI Attrs" { pi.last_name }
# "Ketchum"
```

```ruby
class PatientInfoTwo < PatientInfo
  exclude_from_phi :created_at
end

pi = PatientInfoTwo.new(first_name: "Ash", last_name: "Ketchum")
pi.created_at
# current time
pi.last_name
# PHIAccessException!
pi.allow_phi "Ash", "Testing PHI Attrs" { pi.last_name }
# "Ketchum"
```

```ruby
class PatientInfoThree < PatientInfoTwo
  include_in_phi :created_at # Changed our mind
end

pi = PatientInfoThree.new(first_name: "Ash", last_name: "Ketchum")
pi.created_at
# PHIAccessException!
pi.last_name
# PHIAccessException!
pi.allow_phi "Ash", "Testing PHI Attrs" { pi.last_name }
# "Ketchum"
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

### Check If PHI Access Is Allowed

To check if PHI is allowed for a particular instance of a class call `phi_allowed?`.

```ruby
patient = Patient.new
patient.phi_allowed? # => false

patient.allow_phi('user@example.com', 'reason') do
  patient.phi_allowed? # => true
end

patient.phi_allowed? # => false

patient.allow_phi!('user@example.com', 'reason')
patient.phi_allowed? # => true
```

This also works if access was granted at the class level:

```ruby
patient = Patient.new
patient.phi_allowed? # => false
Patient.allow_phi!('user@example.com', 'reason')
patient.phi_allowed? # => true
```

There is also a `phi_allowed?` check available to see at the class level.

```ruby
Patient.phi_allowed? # => false
Patient.allow_phi!('user@example.com', 'reason')
Patient.phi_allowed? # => true
```

**Note that any instance level access grants will not change class level access:**

```ruby
patient = Patient.new

patient.phi_allowed? # => false
Patient.phi_allowed? # => false

patient.allow_phi!('user@example.com', 'reason')

patient.phi_allowed? # => true
Patient.phi_allowed? # => false
```


### Revoking PHI Access

You can remove access to PHI with `disallow_phi!`. Each `disallow_phi!` call removes all access granted by `allow_phi!` at that level (class or instance).

At a class level:

```ruby
Patient.disallow_phi!
```

Or at a instance level:

```ruby
patient.disallow_phi!
```

* *If access is granted at both class and instance level you will need to call `disallow_phi!` twice, once for the instance and once for the class.*

There is also a block syntax of `disallow_phi` for temporary suppression phi access to the class or instance level

```ruby
patient = PatientInfo.find(params[:id])
patient.allow_phi!('allowed_user@example.com', 'Display Patient Data')
patient.diallow_phi do
  @data = patient.to_json # PHIAccessException
end # Access is allowed again beyond this point
```

or a block level on a class:

```ruby
PatientInfo.allow_phi!('allowed_user@example.com', 'Display Patient Data')
PatientInfo.diallow_phi do
  @data = PatientInfo.find(params[:id]).to_json # PHIAccessException
end # Access is allowed again beyond this point
```

* *Reminder instance level `phi_allow` will take precedent over a class level `disallow_phi`*

### Manual PHI Access Logging

If you aren't using `phi_record` you can still use `phi_attrs` to manually log phi access in your application. Where ever you are granting PHI access call:

```ruby
user = 'user@example.com'
message = 'accessed list of all patients'
PhiAttrs.log_phi_access(user, message)
```

### Default User

Passing around the current user can clutter your code. PHI Attrs allows you to
configure a controller method that will be called to get the currently logged in
user:

#### `config/initializers/phi_attrs.rb`

```ruby
PhiAttrs.configure do |conf|
  conf.current_user_method = :user_email
end
```

#### `app/controllers/home_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  private

  def user_email
    current_user&.email
  end
end
```

With the above code, any call to `allow_phi` (that starts in a controller
derived from ApplicationController) will use the result of `user_email` as the
user argument of `allow_phi`.

### Reason Translations

It can get cumbersome to pass around PHI Access reasons. PHI Attrs allows you to
use your translations file to keep your code dry. If your translation file
contains a reason for the combination of controller, action, and model you can
skip passing `reason`:

```ruby
module Admin
  class PatientDashboardController < ApplicationController
    def expelliarmus
      patient_info.allow_phi(current_user) do
        # reason tries to use `phi.admin.patient_dashbaord.expelliarmus.patient_info`
      end
    end

    def leviosa
      patient_info.allow_phi(current_user) do
        # reason tries to use `phi.admin.patient_dashbaord.expelliarmus.patient_info`
      end
    end
  end
end
```

The following `en.yml` file would work:

```yml
en:
  phi:
    admin:
      patient_dashboard:
        expelliarmus:
          patient_info: "Patient Disarmed"
        leviosa:
          patient_info: "Patient Levitated"
```

If you have a typo in your en.yml file or you choose not to provide a translation
for your phi reasons your code will fail with an ArgumentError. To assist you in
debugging PHI Attrs will print a `:warn` message with the expected location for
the missing translation.

## Best Practices

* Mix and matching `instance`, `class` and `block` syntaxes for allowing/denying PHI is not recommended.
  * Sticking with one style in your application will make it easier to understand what access is granted and where.

## Development

It is recommended to use the provided `docker-compose` environment for development to help ensure dependency consistency and code isolation from other projects you may be working on.

### Begin

    $ docker-compose up
    $ bin/ssh_to_container

### Tests

Tests are written using [RSpec](http://rspec.info/) and are setup to use [Appraisal](https://github.com/thoughtbot/appraisal) to run tests over multiple rails versions.

    $ bin/run_tests
    or for individual tests:
    $ bin/ssh_to_container
    $ bundle exec appraisal rspec spec/path/to/spec.rb

### Console

An interactive prompt that will allow you to experiment with the gem.

    $ bin/ssh_to_container
    $ bin/console

### Local Install

Run `bin/setup` to install dependencies. Then, run `bundle exec appraisal rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Versioning

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/apsislabs/phi_attrs.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Legal Disclaimer

Apsis Labs, LLP is not a law firm and does not provide legal advice. The information in this repo and software does not constitute legal advice, nor does usage of this software create an attorney-client relationship.

Apsis Labs, LLP is not a HIPAA covered entity, and usage of this software does not create a business associate relationship, nor does it enact a business associate agreement.

---

# Built by Apsis

[![apsis](https://s3-us-west-2.amazonaws.com/apsiscdn/apsis.png)](https://www.apsis.io)

`phi_attrs` was built by Apsis Labs. We love sharing what we build! Check out our [other libraries on Github](https://github.com/apsislabs), and if you like our work you can [hire us](https://www.apsis.io/work-with-us/) to build your vision.
