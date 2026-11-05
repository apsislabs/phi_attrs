# frozen_string_literal: true

# ActiveSupport 7.0, 7.1 and 8.0 call `JSON.generate(..., quirks_mode: true)`.
# json 3 removed that option and raises `ArgumentError: unknown keyword:
# quirks_mode`, so `render json:` fails in the controller specs. This is a bug
# in those Rails versions, not in phi_attrs. Rails 7.2.4+ no longer passes the
# option.
#
# Applies only when the installed ActiveSupport still passes the option and json
# rejects it, so it switches itself off on fixed versions. Delete it once
# those Rails versions are dropped or patched.
if defined?(ActiveSupport::JSON::Encoding::JSONGemEncoder) &&
    Gem::Version.new(JSON::VERSION) >= Gem::Version.new("3")
  encoder = ActiveSupport::JSON::Encoding::JSONGemEncoder
  file, = encoder.instance_method(:stringify).source_location if encoder.private_method_defined?(:stringify)

  if file && File.read(file).include?("quirks_mode: true")
    encoder.prepend(
      Module.new do
        private

        def stringify(jsonified)
          ::JSON.generate(jsonified, max_nesting: false)
        end
      end
    )
  end
end
