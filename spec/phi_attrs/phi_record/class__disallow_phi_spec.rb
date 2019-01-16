# frozen_string_literal: true

RSpec.describe 'class disallow_phi' do
  file_name = __FILE__

  let(:patient_jane) { build(:patient_info, first_name: 'Jane') }
  let(:patient_john) { build(:patient_info, first_name: 'John') }

  context 'block' do
    it 'disables all allowances within the block' do |t|
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { patient_jane.first_name }.not_to raise_error

      PatientInfo.disallow_phi do
        expect { patient_jane.first_name }.to raise_error(access_error)
      end
    end

    it 'returns permission after the block' do |t|
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { patient_jane.first_name }.not_to raise_error

      PatientInfo.disallow_phi do
        expect { patient_jane.first_name }.to raise_error(access_error)
      end

      expect { patient_jane.first_name }.not_to raise_error
    end

    it 'does not affect explicit instance allow' do |t|
      PatientInfo.allow_phi!(file_name, t.full_description)
      patient_john.allow_phi!(file_name, t.full_description)

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_john.first_name }.not_to raise_error

      PatientInfo.disallow_phi do
        expect { patient_jane.first_name }.to raise_error(access_error)
        expect { patient_john.first_name }.not_to raise_error
      end

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_john.first_name }.not_to raise_error
    end

    it 'raises ArgumentError without block' do
      expect { PatientInfo.disallow_phi }.to raise_error(ArgumentError)
    end
  end

  context 'disallow_phi!' do
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

    it 'raises ArgumentError with block' do
      expect { PatientInfo.disallow_phi! {} }.to raise_error(ArgumentError)
    end
  end
end
