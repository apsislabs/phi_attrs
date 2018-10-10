# frozen_string_literal: true

module ErrorHelpers
  def access_error
    PhiAttrs::Exceptions::PhiAccessException
  end
end

RSpec.configure do |config|
  config.include ErrorHelpers
end
