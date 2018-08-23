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

    it 'should log multiple times for nested allow_phi calls' do
      expect(PhiAttrs::Logger.logger).to receive(:info).exactly(6)

      PatientInfo.allow_phi('test', 'unit test one') do # Logged allowed
        patient_jane.first_name # Logged access
        PatientInfo.allow_phi('test', 'illegal phi harvesting') do # Logged allowed
          patient_jane.birthday # Logged Access
        end # Logged Disallowed
      end # Logged Disallowed
    end
  end

  context 'instance authorized' do
    context 'single record' do
      it 'allows access to an authorized instance' do
        expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

        patient_jane.allow_phi('test', 'unit tests') do
          expect { patient_jane.first_name }.not_to raise_error
        end

        expect { patient_jane.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

        patient_jane.allow_phi! 'test', 'unit tests'

        expect { patient_jane.first_name }.not_to raise_error
      end

      it 'only allows access to the authorized instance' do
        patient_jane.allow_phi('test', 'unit tests') do
          expect { patient_jane.first_name }.not_to raise_error
          expect { patient_john.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
        end

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

      it 'allows access on an instance that already exists' do
        john = PatientInfo.create(first_name: 'John', last_name: 'Doe')
        expect { john.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

        john_id = john.id
        john = nil

        john = PatientInfo.find(john_id)
        expect { john.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

        john.allow_phi! 'test', 'unit tests'
        expect { john.first_name }.not_to raise_error
        expect(john.first_name).to eq 'John'
      end
    end

    context 'collection' do
      let(:jay) { PatientInfo.create(first_name: "Jay") }
      let(:bob) { PatientInfo.create(first_name: "Bob") }
      let(:moe) { PatientInfo.create(first_name: "Moe") }
      let(:patients) { [jay, bob, moe] }

      it 'allows access when fetched as a collection' do
        expect(patients).to contain_exactly(jay, bob, moe)
        expect { patients.map(&:first_name) }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

        patients.map { |p| p.allow_phi! 'test', 'unit tests' }
        expect { patients.map(&:first_name) }.not_to raise_error
      end

      context 'with targets' do
        let(:non_target) { PatientInfo.create(first_name: 'Private') }

        it 'allow_phi allows access to all members of a collection' do
          patients.each do |patient|
            expect { patient.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
          end

          expect {
            PatientInfo.allow_phi(patients, 'test', 'unit tests') do
              expect(patients.map(&:first_name)).to contain_exactly("Jay", "Bob", "Moe")
            end
          }.not_to raise_error
        end

        it 'allow_phi does not allow access to non-targets' do
          expect { non_target.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

          expect {
            PatientInfo.allow_phi(patients, 'test', 'unit tests') do
              expect { non_target.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
            end
          }.not_to raise_error
        end
      end
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

  context 'extended authorization' do
    let(:mary_detail)  { PatientDetail.create(detail: 'Lorem Ipsum') }
    let(:mary_address) { Address.create(address: '123 Street Ave') }
    let(:patient_mary) { PatientInfo.create(first_name: 'Mary', last_name: 'Jay', address: mary_address, patient_detail: mary_detail) }

    it 'extends access to extended association' do
      expect { patient_mary.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
      expect { patient_mary.patient_detail.detail }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      patient_mary.allow_phi! 'test', 'unit tests'

      expect { patient_mary.first_name }.not_to raise_error
      expect { patient_mary.patient_detail.detail }.not_to raise_error
      expect(patient_mary.patient_detail.detail).to eq 'Lorem Ipsum'
    end

    it 'does not extend to unextended association' do
      expect { patient_mary.first_name }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)
      expect { patient_mary.address.address }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      patient_mary.allow_phi! 'test', 'unit tests'
      expect { patient_mary.first_name }.not_to raise_error
      expect { patient_mary.address.address }.to raise_error(PhiAttrs::Exceptions::PhiAccessException)

      patient_mary.address.allow_phi! 'test', 'unit test'
      expect { patient_mary.address.address }.not_to raise_error
      expect(patient_mary.address.address).to eq '123 Street Ave'
    end
  end
end
