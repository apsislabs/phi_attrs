# frozen_string_literal: true

RSpec.describe 'instance allow_phi' do
  file_name = __FILE__

  let(:patient_john) { build(:patient_info, first_name: 'John') }
  let(:patient_jane) { build(:patient_info, first_name: 'Jane') }
  let(:patient_detail) { build(:patient_detail) }
  let(:patient_with_detail) { build(:patient_info, first_name: 'Jack', patient_detail: patient_detail) }

  context 'authorized' do
    context 'single record' do
      it 'allows access to an authorized instance' do |t|
        expect { patient_jane.first_name }.to raise_error(access_error)

        patient_jane.allow_phi(file_name, t.full_description) do
          expect { patient_jane.first_name }.not_to raise_error
        end

        expect { patient_jane.first_name }.to raise_error(access_error)

        patient_jane.allow_phi!(file_name, t.full_description)

        expect { patient_jane.first_name }.not_to raise_error
      end

      it 'only allows access to the authorized instance' do |t|
        patient_jane.allow_phi(file_name, t.full_description) do
          expect { patient_jane.first_name }.not_to raise_error
          expect { patient_john.first_name }.to raise_error(access_error)
        end

        patient_jane.allow_phi!(file_name, t.full_description)

        expect { patient_jane.first_name }.not_to raise_error
        expect { patient_john.first_name }.to raise_error(access_error)
      end

      it 'revokes access after calling disallow_phi!' do |t|
        expect { patient_jane.first_name }.to raise_error(access_error)

        patient_jane.allow_phi!(file_name, t.full_description)

        expect { patient_jane.first_name }.not_to raise_error

        patient_jane.disallow_phi!

        expect { patient_jane.first_name }.to raise_error(access_error)
      end

      it 'allows access on an instance that already exists' do |t|
        john = create(:patient_info, first_name: 'John')
        expect { john.first_name }.to raise_error(access_error)

        john_id = john.id
        john = nil

        john = PatientInfo.find(john_id)
        expect { john.first_name }.to raise_error(access_error)

        john.allow_phi!(file_name, t.full_description)
        expect { john.first_name }.not_to raise_error
        expect(john.first_name).to eq 'John'
      end

      it 'rejects calls to allow_phi! with blank values' do
        expect { patient_jane.allow_phi! '', '' }.to raise_error(ArgumentError)
        expect { patient_jane.allow_phi! 'ok', '' }.to raise_error(ArgumentError)
        expect { patient_jane.allow_phi! '', 'ok' }.to raise_error(ArgumentError)
        expect { patient_jane.allow_phi! 'ok', 'ok' }.not_to raise_error
      end

      it 'persists after a reload' do |t|
        dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail))
        dumbledore.allow_phi(file_name, t.full_description) do
          expect { dumbledore.first_name }.not_to raise_error
          dumbledore.reload
          expect { dumbledore.first_name }.not_to raise_error
        end
      end

      it 'persists extended phi after a reload' do |t|
        dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail, :all_random))
        dumbledore.allow_phi(file_name, t.full_description) do
          expect { dumbledore.patient_detail.detail }.not_to raise_error
          dumbledore.reload
          expect { dumbledore.patient_detail.detail }.not_to raise_error
        end
      end
    end

    context 'collection' do
      let(:jay) { create(:patient_info, first_name: 'Jay') }
      let(:bob) { create(:patient_info, first_name: 'Bob') }
      let(:moe) { create(:patient_info, first_name: 'Moe') }
      let(:patients) { [jay, bob, moe] }

      it 'allows access when fetched as a collection' do |t|
        expect(patients).to contain_exactly(jay, bob, moe)
        expect { patients.map(&:first_name) }.to raise_error(access_error)

        patients.map { |p| p.allow_phi!(file_name, t.full_description) }
        expect { patients.map(&:first_name) }.not_to raise_error
      end

      context 'with targets' do
        let(:non_target) { create(:patient_info, first_name: 'Private') }

        it 'allow_phi allows access to all members of a collection' do |t|
          patients.each do |patient|
            expect { patient.first_name }.to raise_error(access_error)
          end

          expect do
            PatientInfo.allow_phi(file_name, t.full_description, allow_only: patients) do
              expect(patients.map(&:first_name)).to contain_exactly('Jay', 'Bob', 'Moe')
            end
          end.not_to raise_error
        end

        it 'allow_phi does not allow access to non-targets' do |t|
          expect { non_target.first_name }.to raise_error(access_error)

          expect do
            PatientInfo.allow_phi(file_name, t.full_description, allow_only: patients) do
              expect { non_target.first_name }.to raise_error(access_error)
            end
          end.not_to raise_error
        end

        context 'invalid targets' do
          it 'raises exception when targeting an unexpected class' do |t|
            address = create(:address)

            expect do
              PatientInfo.allow_phi(file_name, t.full_description, allow_only: [jay, address]) do
                jay.first_name
              end
            end.to raise_error(ArgumentError)
          end

          it 'raises exception when given a non-iterable' do |t|
            expect do
              PatientInfo.allow_phi(file_name, t.full_description, allow_only: jay) do
                jay.first_name
              end
            end.to raise_error(ArgumentError)
          end
        end
      end
    end
  end

  context 'extended authorization' do
    let(:patient_mary) { create(:patient_info, :with_multiple_health_records) }

    context 'plain access' do
      it 'extends access to extended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.patient_detail.detail }.to raise_error(access_error)

        patient_mary.allow_phi!(file_name, t.full_description)

        expect { patient_mary.first_name }.not_to raise_error
        expect { patient_mary.patient_detail.detail }.not_to raise_error
        expect(patient_mary.patient_detail.detail).to eq 'Generic Spell'
      end

      it 'does not extend to unextended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.address.address }.to raise_error(access_error)

        patient_mary.allow_phi!(file_name, t.full_description)
        expect { patient_mary.first_name }.not_to raise_error
        expect { patient_mary.address.address }.to raise_error(access_error)

        patient_mary.address.allow_phi!(file_name, t.full_description)
        expect { patient_mary.address.address }.not_to raise_error
        expect(patient_mary.address.address).to eq '123 Little Whinging'
      end

      it 'extends access to :has_many associations' do |t|
        expect { patient_mary.health_records.first.data }.to raise_error(access_error)

        patient_mary.allow_phi!(file_name, t.full_description)
        expect { patient_mary.health_records.first.data }.not_to raise_error
      end
    end

    context 'block access' do
      it 'extends access to extended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.patient_detail.detail }.to raise_error(access_error)

        patient_mary.allow_phi(file_name, t.full_description) do
          expect { patient_mary.first_name }.not_to raise_error
          expect { patient_mary.patient_detail.detail }.not_to raise_error
          expect(patient_mary.patient_detail.detail).to eq('Generic Spell')
        end
      end

      it 'does not extend to unextended association' do |t|
        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.address.address }.to raise_error(access_error)

        patient_mary.allow_phi(file_name, t.full_description) do
          expect { patient_mary.first_name }.not_to raise_error
          expect { patient_mary.address.address }.to raise_error(access_error)
        end

        patient_mary.address.allow_phi!(file_name, t.full_description)
        expect { patient_mary.address.address }.not_to raise_error
        expect(patient_mary.address.address).to eq('123 Little Whinging')
      end

      it 'extends access to :has_many associations' do |t|
        expect { patient_mary.health_records.first.data }.to raise_error(access_error)

        patient_mary.allow_phi(file_name, t.full_description) do
          expect { patient_mary.health_records.first.data }.not_to raise_error
        end
      end

      it 'revokes access after block' do |t|
        patient_mary.allow_phi(file_name, t.full_description) do
          expect { patient_mary.patient_detail.detail }.not_to raise_error
          expect(patient_mary.patient_detail.detail).to eq('Generic Spell')
        end

        expect { patient_mary.first_name }.to raise_error(access_error)
        expect { patient_mary.patient_detail.detail }.to raise_error(access_error)
        expect { patient_mary.health_records.first.data }.to raise_error(access_error)
      end

      it 'does not revoke access for untouched associations' do |t|
        # Here we extend access to two different associations.
        # When the block terminates, it should revoke (the one frame of) the `health_records` access,
        # but it should NOT revoke (the only frame of) the `patient_detail` access.
        # In either case, the "parent" object should still be able to re-extend access.

        patient_mary.allow_phi!(file_name, t.full_description)
        expect { patient_mary.patient_detail.detail }.not_to raise_error
        pd = patient_mary.patient_detail

        patient_mary.allow_phi(file_name, t.full_description) do
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
    it 'retains outer access when disallowed at inner level' do |t|
      patient_with_detail.allow_phi(file_name, t.full_description) do
        expect { patient_with_detail.first_name }.not_to raise_error

        patient_with_detail.allow_phi(file_name, t.full_description) do
          expect { patient_with_detail.first_name }.not_to raise_error
        end # Inner permission revoked

        expect { patient_with_detail.first_name }.not_to raise_error
        expect { patient_with_detail.patient_detail.detail }.not_to raise_error
      end # Outer permission revoked

      expect { patient_with_detail.first_name }.to raise_error(access_error)
      expect { patient_with_detail.patient_detail.detail }.to raise_error(access_error)
    end
  end

  context 'block checks' do
    context 'allow_phi' do
      it 'succeeds' do
        expect { patient_jane.allow_phi!('ok', 'ok') }.not_to raise_error
      end
      it 'raises ArgumentError with block' do
        expect { patient_jane.allow_phi!('ok', 'ok') {} }.to raise_error(ArgumentError)
      end
    end

    context 'allow_phi!' do
      it 'succeeds' do
        expect { patient_jane.allow_phi('ok', 'ok') {} }.not_to raise_error
      end
      it 'raises ArgumentError for allow_phi! without block' do
        expect { patient_jane.allow_phi('ok', 'ok') }.to raise_error(ArgumentError)
      end
    end
  end
end
