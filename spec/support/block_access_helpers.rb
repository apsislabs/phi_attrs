# frozen_string_literal: true

module BlockAccessHelpers
  def do_nothing
    # dummy method to put inside "empty" blocks for block-based access specs
  end
end

RSpec.configure do |config|
  config.include BlockAccessHelpers
end
