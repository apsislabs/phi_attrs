FILENAME = __FILE__

RSpec.describe PhiAttrs do
  let(:patient_john) { build(:patient_info, :john) }
  let(:patient_jane) { build(:patient_info, :jane) }
  let(:patient_detail) { build(:patient_detail) }
  let(:patient_with_detail) { build(:patient_info, :jack, patient_detail: patient_detail) }

  it 'has a version number' do
    expect(PhiAttrs::VERSION).not_to be nil
  end

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

  context 'logging' do
    it 'should log an error when raising an exception' do
      patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
      expect(PhiAttrs::Logger.logger).to receive(:error).with('my error message')

      expect {
        raise PhiAttrs::Exceptions::PhiAccessException, 'my error message'
      }.to raise_error(access_error)
    end

    it 'should log an error for unauthorized access' do
      expect(PhiAttrs::Logger.logger).to receive(:error)
      expect { patient_john.birthday }.to raise_error(access_error)
    end

    it 'should log when granting phi to instance' do |t|
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.allow_phi!(FILENAME, t.full_description)
    end

    it 'should log when granting phi to class' do |t|
      patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
      expect(PhiAttrs::Logger.logger).to receive(:info)
      PatientInfo.allow_phi!(FILENAME, t.full_description)
    end

    it 'should log when revokes phi to class' do
      patient_john # TODO Clean up: Logger.logger isn't defined unless we load something tagged with phi_attrs
      expect(PhiAttrs::Logger.logger).to receive(:info)
      PatientInfo.disallow_phi!
    end

    it 'should log when accessing method' do |t|
      PatientInfo.allow_phi!(FILENAME, t.full_description)
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.first_name
    end

    it 'should log once when accessing multiple methods' do |t|
      PatientInfo.allow_phi!(FILENAME, t.full_description)
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.first_name
      patient_jane.birthday
    end

    it 'should log object_id for unpersisted' do |t|
      PatientInfo.allow_phi!(FILENAME, t.full_description)
      expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Object: #{patient_jane.object_id}").and_call_original
      expect(PhiAttrs::Logger.logger).to receive(:info)
      patient_jane.first_name
    end

    it 'should log id for persisted' do |t|
      PatientInfo.allow_phi!(FILENAME, t.full_description)
      patient_jane.save
      expect(patient_jane.persisted?).to be true
      expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Key: #{patient_jane.id}").and_call_original
      expect(PhiAttrs::Logger.logger).to receive(:info).and_call_original
      patient_jane.first_name
    end

    it 'should log multiple times for nested allow_phi calls' do |t|
      expect(PhiAttrs::Logger.logger).to receive(:info).exactly(6)

      PatientInfo.allow_phi(FILENAME, t.full_description) do # Logged allowed
        patient_jane.first_name # Logged access
        PatientInfo.allow_phi(FILENAME, t.full_description) do # Logged allowed
          patient_jane.birthday # Logged Access
        end # Logged Disallowed
      end # Logged Disallowed
    end
  end

  context 'instance authorized' do
    context 'single record' do
      it 'allows access to an authorized instance' do |t|
        expect { patient_jane.first_name }.to raise_error(access_error)

        patient_jane.allow_phi(FILENAME, t.full_description) do
          expect { patient_jane.first_name }.not_to raise_error
        end

        expect { patient_jane.first_name }.to raise_error(access_error)

        patient_jane.allow_phi!(FILENAME, t.full_description)

        expect { patient_jane.first_name }.not_to raise_error
      end

      it 'only allows access to the authorized instance' do |t|
        patient_jane.allow_phi(FILENAME, t.full_description) do
          expect { patient_jane.first_name }.not_to raise_error
          expect { patient_john.first_name }.to raise_error(access_error)
        end

        patient_jane.allow_phi!(FILENAME, t.full_description)

        expect { patient_jane.first_name }.not_to raise_error
        expect { patient_john.first_name }.to raise_error(access_error)
      end

      it 'revokes access after calling disallow_phi!' do |t|
        expect { patient_jane.first_name }.to raise_error(access_error)

        patient_jane.allow_phi!(FILENAME, t.full_description)

        expect { patient_jane.first_name }.not_to raise_error

        patient_jane.disallow_phi!

        expect { patient_jane.first_name }.to raise_error(access_error)
      end

      it 'allows access on an instance that already exists' do |t|
        john = PatientInfo.create(first_name: 'John', last_name: 'Doe')
        expect { john.first_name }.to raise_error(access_error)

        john_id = john.id
        john = nil

        john = PatientInfo.find(john_id)
        expect { john.first_name }.to raise_error(access_error)

        john.allow_phi!(FILENAME, t.full_description)
        expect { john.first_name }.not_to raise_error
        expect(john.first_name).to eq 'John'
      end

      it 'rejects calls to allow_phi! with blank values' do
        expect { patient_jane.allow_phi! '', '' }.to raise_error(ArgumentError)
        expect { patient_jane.allow_phi! 'ok', '' }.to raise_error(ArgumentError)
        expect { patient_jane.allow_phi! '', 'ok' }.to raise_error(ArgumentError)
        expect { patient_jane.allow_phi! 'ok', 'ok' }.not_to raise_error
      end
    end

    context 'collection' do
      let(:jay) { PatientInfo.create(first_name: "Jay") }
      let(:bob) { PatientInfo.create(first_name: "Bob") }
      let(:moe) { PatientInfo.create(first_name: "Moe") }
      let(:patients) { [jay, bob, moe] }

      it 'allows access when fetched as a collection' do |t|
        expect(patients).to contain_exactly(jay, bob, moe)
        expect { patients.map(&:first_name) }.to raise_error(access_error)

        patients.map { |p| p.allow_phi!(FILENAME, t.full_description) }
        expect { patients.map(&:first_name) }.not_to raise_error
      end

      context 'with targets' do
        let(:non_target) { PatientInfo.create(first_name: 'Private') }

        it 'allow_phi allows access to all members of a collection' do |t|
          patients.each do |patient|
            expect { patient.first_name }.to raise_error(access_error)
          end

          expect {
            PatientInfo.allow_phi(FILENAME, t.full_description, allow_only: patients) do
              expect(patients.map(&:first_name)).to contain_exactly("Jay", "Bob", "Moe")
            end
          }.not_to raise_error
        end

        it 'allow_phi does not allow access to non-targets' do |t|
          expect { non_target.first_name }.to raise_error(access_error)

          expect {
            PatientInfo.allow_phi(FILENAME, t.full_description, allow_only: patients) do
              expect { non_target.first_name }.to raise_error(access_error)
            end
          }.not_to raise_error
        end

        context 'invalid targets' do
          it 'raises exception when targeting an unexpected class' do |t|
            address = Address.create

            expect {
              PatientInfo.allow_phi(FILENAME, t.full_description, allow_only: [jay, address]) do
                jay.first_name
              end
            }.to raise_error(ArgumentError)
          end

          it 'raises exception when given a non-iterable' do |t|
            expect {
              PatientInfo.allow_phi(FILENAME, t.full_description, allow_only: jay) do
                jay.first_name
              end
            }.to raise_error(ArgumentError)
          end
        end
      end
    end
  end

  context 'class authorized' do
    it 'allows access to any instance' do |t|
      expect { patient_jane.first_name }.to raise_error(access_error)
      PatientInfo.allow_phi(FILENAME, t.full_description) do
        expect { patient_jane.first_name }.not_to raise_error
      end

      PatientInfo.allow_phi!(FILENAME, t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
    end

    it 'only allows access to the authorized class' do |t|
      expect { patient_detail.detail }.to raise_error(access_error)
      expect { patient_jane.first_name }.to raise_error(access_error)

      PatientInfo.allow_phi(FILENAME, t.full_description) do
        expect { patient_jane.first_name }.not_to raise_error
        expect { patient_detail.detail }.to raise_error(access_error)
      end

      expect { patient_detail.detail }.to raise_error(access_error)
      expect { patient_jane.first_name }.to raise_error(access_error)

      PatientInfo.allow_phi!(FILENAME, t.full_description)

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_detail.detail }.to raise_error(access_error)
    end

    it 'revokes access after calling disallow_phi!' do |t|
      expect { patient_jane.first_name }.to raise_error(access_error)

      PatientInfo.allow_phi!(FILENAME, t.full_description)

      expect { patient_jane.first_name }.not_to raise_error

      PatientInfo.disallow_phi!

      expect { patient_jane.first_name }.to raise_error(access_error)
    end

    it 'raises ArgumentError for allow_phi! with blank values' do
      expect { PatientInfo.allow_phi! '', '' }.to raise_error(ArgumentError)
      expect { PatientInfo.allow_phi! 'ok', '' }.to raise_error(ArgumentError)
      expect { PatientInfo.allow_phi! '', 'ok' }.to raise_error(ArgumentError)
      expect { PatientInfo.allow_phi! 'ok', 'ok' }.not_to raise_error
    end
  end

  context 'extended authorization' do
    let(:mary_detail)  { PatientDetail.create(detail: 'Lorem Ipsum') }
    let(:mary_address) { Address.create(address: '123 Street Ave') }
    let(:mary_record_1) { HealthRecord.create(data: 'dolor sit amet') }
    let(:mary_record_2) { HealthRecord.create(data: 'consectetur adipiscing elit') }
    let(:patient_mary) { PatientInfo.create(first_name: 'Mary', last_name: 'Jay', address: mary_address, patient_detail: mary_detail, health_records: [mary_record_1, mary_record_2]) }

    context 'plain access' do
      it 'extends access to extended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.patient_detail.detail }.to raise_error(access_error)

        patient_mary.allow_phi!(FILENAME, t.full_description)

        expect { patient_mary.first_name }.not_to raise_error
        expect { patient_mary.patient_detail.detail }.not_to raise_error
        expect(patient_mary.patient_detail.detail).to eq 'Lorem Ipsum'
      end

      it 'does not extend to unextended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.address.address }.to raise_error(access_error)

        patient_mary.allow_phi!(FILENAME, t.full_description)
        expect { patient_mary.first_name }.not_to raise_error
        expect { patient_mary.address.address }.to raise_error(access_error)

        patient_mary.address.allow_phi!(FILENAME, t.full_description)
        expect { patient_mary.address.address }.not_to raise_error
        expect(patient_mary.address.address).to eq '123 Street Ave'
      end

      it 'extends access to :has_many associations' do |t|
        expect { patient_mary.health_records.first.data }.to raise_error(access_error)

        patient_mary.allow_phi!(FILENAME, t.full_description)
        expect { patient_mary.health_records.first.data }.not_to raise_error
      end
    end

    context 'block access' do
      it 'extends access to extended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.patient_detail.detail }.to raise_error(access_error)

        patient_mary.allow_phi(FILENAME, t.full_description) do
          expect { patient_mary.first_name }.not_to raise_error
          expect { patient_mary.patient_detail.detail }.not_to raise_error
          expect(patient_mary.patient_detail.detail).to eq('Lorem Ipsum')
        end
      end

      it 'does not extend to unextended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.address.address }.to raise_error(access_error)

        patient_mary.allow_phi(FILENAME, t.full_description) do
          expect { patient_mary.first_name }.not_to raise_error
          expect { patient_mary.address.address }.to raise_error(access_error)
        end

        patient_mary.address.allow_phi!(FILENAME, t.full_description)
        expect { patient_mary.address.address }.not_to raise_error
        expect(patient_mary.address.address).to eq('123 Street Ave')
      end

      it 'extends access to :has_many associations' do |t|
        expect { patient_mary.health_records.first.data }.to raise_error(access_error)

        patient_mary.allow_phi(FILENAME, t.full_description) do
          expect { patient_mary.health_records.first.data }.not_to raise_error
        end
      end

      it 'revokes access after block' do |t|
        patient_mary.allow_phi(FILENAME, t.full_description) do
          expect { patient_mary.patient_detail.detail }.not_to raise_error
          expect(patient_mary.patient_detail.detail).to eq('Lorem Ipsum')
        end

        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.patient_detail.detail }.to raise_error(access_error)
        expect { patient_mary.health_records.first.data }.to raise_error(access_error)
      end

      it 'does not revoke access for untouched associations (Class level)' do |t|
        # Here we extend access to two different associations.
        # When the block terminates, it should revoke (the one frame of) the `health_records` access,
        # but it should NOT revoke (the only frame of) the `patient_detail` access.
        # In either case, the "parent" object should still be able to re-extend access.

        PatientInfo.allow_phi!(FILENAME, t.full_description)
        expect { patient_mary.patient_detail.detail }.not_to raise_error
        pd = patient_mary.patient_detail

        PatientInfo.allow_phi(FILENAME, t.full_description) do
          expect { patient_mary.health_records.first.data }.not_to raise_error
        end

        # The PatientInfo should re-extend access to `health_records`
        expect { patient_mary.health_records.first.data }.not_to raise_error

        # We should still be able to access this through a different handle,
        # as the PatientDetail model should not have been affected by the end-of-block revocation.
        # The separate handle is important because this does not allow the access to
        # be quietly re-extended by the PatientInfo record.
        expect { pd.detail }.not_to raise_error
      end

      it 'does not revoke access for untouched associations (instance level)' do |t|
        # Here we extend access to two different associations.
        # When the block terminates, it should revoke (the one frame of) the `health_records` access,
        # but it should NOT revoke (the only frame of) the `patient_detail` access.
        # In either case, the "parent" object should still be able to re-extend access.

        patient_mary.allow_phi!(FILENAME, t.full_description)
        expect { patient_mary.patient_detail.detail }.not_to raise_error
        pd = patient_mary.patient_detail

        patient_mary.allow_phi(FILENAME, t.full_description) do
          expect { patient_mary.health_records.first.data }.not_to raise_error
        end

        # The PatientInfo should re-extend access to `health_records`
        expect { patient_mary.health_records.first.data }.not_to raise_error

        # We should still be able to access this through a different handle,
        # as the PatientDetail model should not have been affected by the end-of-block revocation.
        # The separate handle is important because this does not allow the access to
        # be quietly re-extended by the PatientInfo record.
        expect { pd.detail }.not_to raise_error
      end
    end
  end

  context 'nested allowances' do
    context 'class level' do
      it 'retains outer access when disallowed at inner level' do |t|
        PatientInfo.allow_phi(FILENAME, t.full_description) do
          expect { patient_with_detail.first_name }.not_to raise_error

          PatientInfo.allow_phi(FILENAME, t.full_description) do
            expect { patient_with_detail.first_name }.not_to raise_error
          end # Inner permission revoked

          expect { patient_with_detail.first_name }.not_to raise_error
          expect { patient_with_detail.patient_detail.detail }.not_to raise_error
        end # Outer permission revoked

        expect { patient_with_detail.first_name }.to raise_error(access_error)
        expect { patient_with_detail.patient_detail.detail }.to raise_error(access_error)
      end
    end

    context 'instance level' do
      it 'retains outer access when disallowed at inner level' do |t|
        patient_with_detail.allow_phi(FILENAME, t.full_description) do
          expect { patient_with_detail.first_name }.not_to raise_error

          patient_with_detail.allow_phi(FILENAME, t.full_description) do
            expect { patient_with_detail.first_name }.not_to raise_error
          end # Inner permission revoked

          expect { patient_with_detail.first_name }.not_to raise_error
          expect { patient_with_detail.patient_detail.detail }.not_to raise_error
        end # Outer permission revoked

        expect { patient_with_detail.first_name }.to raise_error(access_error)
        expect { patient_with_detail.patient_detail.detail }.to raise_error(access_error)
      end
    end
  end

  context 'disallow block', skip: 'Not yet implemented' do
    it 'disables all allowances within the block' do |t|
      patient_john.allow_phi!(FILENAME, t.full_description)
      expect { patient_john.first_name }.not_to raise_error

      patient_john.disallow_phi do
        expect { patient_john.last_name }.to raise_error(access_error)
      end
    end

    it 'returns permission after the block' do |t|
      patient_john.allow_phi!(FILENAME, t.full_description)
      expect { patient_john.first_name }.not_to raise_error

      patient_john.disallow_phi do
        expect { patient_john.first_name }.to raise_error(access_error)
      end

      expect { patient_john.first_name }.not_to raise_error
    end
  end
end

def access_error
  PhiAttrs::Exceptions::PhiAccessException
end
