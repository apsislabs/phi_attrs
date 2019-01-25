# frozen_string_literal: true

RSpec.describe 'configure' do
  orig_method = nil
  orig_path = nil
  orig_prefix = nil

  before :all do
    orig_method = PhiAttrs.current_user_method
    orig_path = PhiAttrs.log_path
    orig_prefix = PhiAttrs.translation_prefix

    PhiAttrs.configure do |c|
      c.current_user_method = nil
      c.log_path = nil
      c.translation_prefix = nil
    end
  end

  after :all do
    PhiAttrs.configure do |c|
      c.current_user_method = orig_method
      c.log_path = orig_path
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

  context 'translation prefix' do
    subject(:translation_prefix) { PhiAttrs.translation_prefix }

    it { is_expected.to eq(nil) }

    it 'can be set' do
      PhiAttrs.configure { |c| c.translation_prefix = 'phi_gem' }
      expect(translation_prefix).to be('phi_gem')
    end
  end
end
