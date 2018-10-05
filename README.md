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

## Legal Disclaimer

Apsis Labs, LLP is not a law firm and does not provide legal advice. The information in this repo and software does not constitute legal advice, nor does usage of this software create an attorney-client relationship.

Apsis Labs, LLP is not a HIPAA covered entity, and usage of this software does not create a business associate relationship, nor does it enact a business associate agreement.

---

# Built by Apsis

[![apsis](https://s3-us-west-2.amazonaws.com/apsiscdn/apsis.png)](https://www.apsis.io)

`phi_attrs` was built by Apsis Labs. We love sharing what we build! Check out our [other libraries on Github](https://github.com/apsislabs), and if you like our work you can [hire us](https://www.apsis.io/work-with-us/) to build your vision.
