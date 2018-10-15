# frozen_string_literal: true

RSpec.describe 'exceptions' do
  let(:patient_john) { build(:patient_info, first_name: 'John') }

  context 'unauthorized' do
    it 'raises an error on default attribute' do
      expect { patient_john.first_name }.to raise_error(access_error)
    end

    it 'raises an error on included method' do
      expect { patient_john.birthday }.to raise_error(access_error)
    end

    it 'does not raise an error on excluded attribute' do
      expect { patient_john.last_name }.not_to raise_error
    end
  end
end
