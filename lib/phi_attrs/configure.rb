# frozen_string_literal: true

module PhiAttrs
  mattr_accessor :log_path, default: nil
  mattr_accessor :log_shift_age, default: 0
  mattr_accessor :log_shift_size, default: 1_048_576
  mattr_accessor :current_user_method, default: nil
  mattr_accessor :translation_prefix, default: "phi"

  def self.configure
    yield self if block_given?
  end
end
