FILENAME = __FILE__

RSpec.describe Logger do
  let(:patient_john) { build(:patient_info, :john) }
  let(:patient_jane) { build(:patient_info, :jane) }

  context 'log' do
    context 'error' do
      it 'when raising an exception' do
        patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
        expect(PhiAttrs::Logger.logger).to receive(:error).with('my error message')

        expect {
          raise PhiAttrs::Exceptions::PhiAccessException, 'my error message'
        }.to raise_error(access_error)
      end

      it 'for unauthorized access' do
        expect(PhiAttrs::Logger.logger).to receive(:error)
        expect { patient_john.birthday }.to raise_error(access_error)
      end
    end

    context 'info' do
      it 'when granting phi to instance' do |t|
        expect(PhiAttrs::Logger.logger).to receive(:info)
        patient_jane.allow_phi!(FILENAME, t.full_description)
      end

      it 'when granting phi to class' do |t|
        patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
        expect(PhiAttrs::Logger.logger).to receive(:info)
        PatientInfo.allow_phi!(FILENAME, t.full_description)
      end

      it 'when revokes phi to class' do
        patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
        expect(PhiAttrs::Logger.logger).to receive(:info)
        PatientInfo.disallow_phi!
      end

      it 'when accessing method' do |t|
        PatientInfo.allow_phi!(FILENAME, t.full_description)
        expect(PhiAttrs::Logger.logger).to receive(:info)
        patient_jane.first_name
      end
    end
    
    context 'identifier' do
        it 'object_id for unpersisted' do |t|
          PatientInfo.allow_phi!(FILENAME, t.full_description)
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Object: #{patient_jane.object_id}").and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:info)
          patient_jane.first_name
        end

        it 'id for persisted' do |t|
          PatientInfo.allow_phi!(FILENAME, t.full_description)
          patient_jane.save
          expect(patient_jane.persisted?).to be true
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Key: #{patient_jane.id}").and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:info).and_call_original
          patient_jane.first_name
        end
    end

    context 'frequency' do
      it 'once when accessing multiple methods' do |t|
        PatientInfo.allow_phi!(FILENAME, t.full_description)
        expect(PhiAttrs::Logger.logger).to receive(:info)
        patient_jane.first_name
        patient_jane.birthday
      end

      it 'multiple times for nested allow_phi calls' do |t|
        expect(PhiAttrs::Logger.logger).to receive(:info).exactly(6)

        PatientInfo.allow_phi(FILENAME, t.full_description) do # Logged allowed
          patient_jane.first_name # Logged access
          PatientInfo.allow_phi(FILENAME, t.full_description) do # Logged allowed
            patient_jane.birthday # Logged Access
          end # Logged Disallowed
        end # Logged Disallowed
      end
  end
  end
end
