# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PhiAttrs do
  context 'gem' do
    it 'has a version number' do
      expect(PhiAttrs::VERSION).not_to be nil
    end
  end
end
