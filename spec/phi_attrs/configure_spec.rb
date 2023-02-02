# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'configure' do
  orig_method = nil
  orig_path = nil
  orig_age = nil
  orig_size = nil
  orig_prefix = nil

  before :all do
    orig_method = PhiAttrs.current_user_method
    orig_path = PhiAttrs.log_path
    orig_age = PhiAttrs.log_shift_age
    orig_size = PhiAttrs.log_shift_size
    orig_prefix = PhiAttrs.translation_prefix

    PhiAttrs.configure do |c|
      c.current_user_method = nil
      c.log_path = nil
      c.log_shift_age = nil
      c.log_shift_size = nil
      c.translation_prefix = nil
    end
  end

  after :all do
    PhiAttrs.configure do |c|
      c.current_user_method = orig_method
      c.log_path = orig_path
      c.log_shift_age = orig_age
      c.log_shift_size = orig_size
      c.translation_prefix = orig_prefix
    end
  end

  context 'current user' do
    subject(:current_user_method) { PhiAttrs.current_user_method }

    it { is_expected.to be_nil }

    it 'can be set' do
      PhiAttrs.configure { |c| c.current_user_method = :phi_user }
      expect(current_user_method).to be(:phi_user)
    end
  end

  context 'log_path' do
    subject(:log_path) { PhiAttrs.log_path }

    it { is_expected.to be_nil }

    it 'can be set' do
      PhiAttrs.configure { |c| c.log_path = 'deep_path' }
      expect(log_path).to be('deep_path')
    end
  end

  context 'log_age' do
    subject(:log_shift_age) { PhiAttrs.log_shift_age }

    it { is_expected.to be_nil }

    it 'can be set' do
      PhiAttrs.configure { |c| c.log_shift_age = 7 }
      expect(log_shift_age).to be(7)
    end
  end

  context 'log_size' do
    subject(:log_shift_size) { PhiAttrs.log_shift_size }

    it { is_expected.to be_nil }

    it 'can be set' do
      PhiAttrs.configure { |c| c.log_shift_size = 100.megabytes }
      expect(log_shift_size).to be(100.megabytes)
    end
  end

  context 'translation prefix' do
    subject(:translation_prefix) { PhiAttrs.translation_prefix }

    it { is_expected.to eq(nil) }

    it 'can be set' do
      PhiAttrs.configure { |c| c.translation_prefix = 'phi_gem' }
      expect(translation_prefix).to be('phi_gem')
    end
  end
end
