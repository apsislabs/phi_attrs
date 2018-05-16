RSpec.describe PhiAttrs do
  let(:patient_john) { PatientInfo.new(first_name: 'John', last_name: 'Doe') }
  let(:patient_jane) { PatientInfo.new(first_name: 'Jane', last_name: 'Doe') }

  it 'has a version number' do
    expect(PhiAttrs::VERSION).not_to be nil
  end

  context 'unauthorized' do
    it 'raises an error on default attribute' do
      expect { patient_john.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'raises an error on included method' do
      expect { patient_john.birthday }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'does not raise an error on excluded attribute' do
      expect { patient_john.last_name }.not_to raise_error
    end
  end

  context 'instance authorized' do
    it 'allows access to an authorized instance' do
      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      patient_jane.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error
    end

    it 'only allows access to the authorized instance' do
      patient_jane.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_john.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'revokes access after calling disallow_phi!' do
      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      patient_jane.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error

      patient_jane.disallow_phi!

      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end
  end

  context 'class authorized' do
    it 'allows access to any instance' do
      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
      PatientInfo.allow_phi! 'test', 'unit tests'
      expect { patient_jane.first_name }.not_to raise_error
    end

    it 'only allows access to the authorized instance' do
      patient_jane.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_john.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'revokes access after calling disallow_phi!' do
      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      patient_jane.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error

      patient_jane.disallow_phi!

      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end
  end
end
