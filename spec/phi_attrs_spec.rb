RSpec.describe PhiAttrs do
  let(:patient_john) { PatientInfo.new(first_name: 'John', last_name: 'Doe') }
  let(:patient_jane) { PatientInfo.new(first_name: 'Jane', last_name: 'Doe') }
  let(:patient_detail) { PatientDetail.new(detail: 'Lorem Ipsum') }

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

  context 'logging' do
    it 'should log an error when raising an exception' do
      patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
      expect(PhiAttrs::Logger.logger).to receive(:error).with('my error message')

      expect {
        raise PhiAttrs::Exceptions::PhiAccessException, 'my error message'
      }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'should log an error for unauthorized access' do
      expect(PhiAttrs::Logger.logger).to receive(:error)
      expect { patient_john.birthday }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'should log when granting phi to instance' do
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.allow_phi! 'test', 'unit tests'
    end

    it 'should log when granting phi to class' do
      patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
      expect(PhiAttrs::Logger.logger).to receive(:info)
      PatientInfo.allow_phi! 'test', 'unit tests'
    end

    it 'should log when revokes phi to class' do
      patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
      expect(PhiAttrs::Logger.logger).to receive(:info)
      PatientInfo.disallow_phi!
    end

    it 'should log when accessing method' do
      PatientInfo.allow_phi! 'test', 'unit tests'
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.first_name
    end

    it 'should log once when accessing multiple methods' do
      PatientInfo.allow_phi! 'test', 'unit tests'
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.first_name
      patient_jane.birthday
    end

    it 'should log object_id for unpersisted' do
      PatientInfo.allow_phi! 'test', 'unit tests'
      expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Object: #{patient_jane.object_id}").and_call_original
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.first_name
    end

    it 'should log id for persisted' do
      PatientInfo.allow_phi! 'test', 'unit tests'
      patient_jane.save
      expect(patient_jane.persisted?).to be true
      expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Key: #{patient_jane.id}").and_call_original
      expect(PhiAttrs::Logger.logger).to receive(:info).and_call_original
      patient_jane.first_name
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

    it 'only allows access to the authorized class' do
      PatientInfo.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_detail.detail }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end

    it 'revokes access after calling disallow_phi!' do
      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      PatientInfo.allow_phi! 'test', 'unit tests'

      expect { patient_jane.first_name }.not_to raise_error

      PatientInfo.disallow_phi!

      expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
    end
  end
end
