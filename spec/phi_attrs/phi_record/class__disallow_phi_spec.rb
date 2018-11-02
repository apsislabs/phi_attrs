# frozen_string_literal: true

RSpec.describe 'class disallow_phi' do
  file_name = __FILE__

  # TODO: Block syntax when implemented

  context 'disallow_phi!' do
    let(:patient_jane) { build(:patient_info, first_name: 'Jane') }

    it 'disallows whole stack' do |t|
      PatientInfo.allow_phi!(file_name + '1', t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
      PatientInfo.allow_phi!(file_name + '2', t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
      PatientInfo.disallow_phi!
      expect { patient_jane.first_name }.to raise_error(access_error)
    end

    it 'disallows does not affect instance allows' do |t|
      PatientInfo.allow_phi!(file_name + '1', t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
      patient_jane.allow_phi!(file_name + '2', t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
      PatientInfo.disallow_phi!
      expect { patient_jane.first_name }.not_to raise_error
    end

    it 'allows access after disallow' do |t|
      PatientInfo.allow_phi!(file_name + '1', t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
      PatientInfo.disallow_phi!
      expect { patient_jane.first_name }.to raise_error(access_error)
      PatientInfo.allow_phi!(file_name + '2', t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
    end
  end
end
