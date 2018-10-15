# frozen_string_literal: true

PhiAttrs.configure do |conf|
  conf.log_path = Rails.root.join('log', 'phi_access.log')
end
