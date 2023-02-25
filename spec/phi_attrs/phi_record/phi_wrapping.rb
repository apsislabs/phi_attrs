# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'phi_wrapping' do
  let(:missing_attribute_model) { build(:missing_attribute_model) }
  let(:missing_extend_model) { build(:missing_extend_model) }

  context 'non existant attributes' do
    it 'wrapping a method' do |_t|
      expect { missing_attribute_model }.not_to raise_error
    end

    it 'extending a model' do |_t|
      expect { missing_extend_model }.to raise_error(NameError)
    end
  end
end
