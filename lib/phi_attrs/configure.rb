# frozen_string_literal: true

module PhiAttrs
  @@log_path = nil
  @@current_user_method = nil
  @@translation_prefix = 'phi'

  def self.configure
    yield self if block_given?
  end

  def self.log_path
    @@log_path
  end

  def self.log_path=(value)
    @@log_path = value
  end

  def self.translation_prefix
    @@translation_prefix
  end

  def self.translation_prefix=(value)
    @@translation_prefix = value
  end

  def self.current_user_method
    @@current_user_method
  end

  def self.current_user_method=(value)
    @@current_user_method = value
  end
end
