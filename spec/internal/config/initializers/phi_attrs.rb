# frozen_string_literal: true

PhiAttrs.configure do |conf|
  conf.log_path = Rails.root.join('log', 'phi_access.log')

  # Log Rotation - disabled by default
  # See: https://apidock.com/ruby/Logger/new/class
  conf.log_shift_age = 0        # 0 == disabled - How many logs to keep of `shift_size`
  conf.log_shift_size = 1048576 # 1MB           - Default from logger class
end
