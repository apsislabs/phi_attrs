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
        expect(patient_jane.phi_allowed?).to be false

        patient_jane.allow_phi(file_name, t.full_description) do
          expect(patient_jane.phi_allowed?).to be true
        end

        expect(patient_jane.phi_allowed?).to be false

        patient_jane.allow_phi!(file_name, t.full_description)

        expect(patient_jane.phi_allowed?).to be true
      end

      it 'only allows access to the authorized instance' do |t|
        patient_jane.allow_phi(file_name, t.full_description) do
          expect(patient_jane.phi_allowed?).to be true
          expect(patient_john.phi_allowed?).to be false
        end

        patient_jane.allow_phi!(file_name, t.full_description)

        expect(patient_jane.phi_allowed?).to be true
        expect(patient_john.phi_allowed?).to be false
      end

      it 'revokes access after calling disallow_phi!' do |t|
        expect(patient_jane.phi_allowed?).to be false

        patient_jane.allow_phi!(file_name, t.full_description)

        expect(patient_jane.phi_allowed?).to be true

        patient_jane.disallow_phi!

        expect(patient_jane.phi_allowed?).to be false
      end

      it 'allows access on an instance that already exists' do |t|
        john = create(:patient_info, first_name: 'John')
        expect(john.phi_allowed?).to be false

        john_id = john.id

        john = PatientInfo.find(john_id)
        expect(john.phi_allowed?).to be false

        john.allow_phi!(file_name, t.full_description)
        expect(john.phi_allowed?).to be true
      end
    end

    context 'collection' do
      let(:jay) { create(:patient_info, first_name: 'Jay') }
      let(:bob) { create(:patient_info, first_name: 'Bob') }
      let(:moe) { create(:patient_info, first_name: 'Moe') }
      let(:patients) { [jay, bob, moe] }

      it 'allows access when fetched as a collection' do |t|
        expect(patients).to contain_exactly(jay, bob, moe)
        expect(patients.map(&:phi_allowed?)).to contain_exactly(false, false, false)

        patients.map { |p| p.allow_phi!(file_name, t.full_description) }
        expect(patients.map(&:phi_allowed?)).to contain_exactly(true, true, true)
      end

      context 'with targets' do
        let(:non_target) { create(:patient_info, first_name: 'Private') }

        it 'allow_phi allows access to all members of a collection' do |t|
          patients.each do |patient|
            expect(patient.phi_allowed?).to be false
          end

          expect do
            PatientInfo.allow_phi(file_name, t.full_description, allow_only: patients) do
              expect(patients.map(&:phi_allowed?)).to contain_exactly(true, true, true)
            end
          end.not_to raise_error
        end

        it 'allow_phi does not allow access to non-targets' do |t|
          expect(non_target.phi_allowed?).to be false

          expect do
            PatientInfo.allow_phi(file_name, t.full_description, allow_only: patients) do
              expect(non_target.phi_allowed?).to be false
            end
          end.not_to raise_error
        end
      end
    end
  end

  context 'extended authorization' do
    let(:patient_mary) { create(:patient_info, :with_multiple_health_records) }

    context 'plain access' do
      it 'extends access to extended association' do |t|
        expect(patient_mary.phi_allowed?).to be false
        expect(patient_mary.patient_detail.phi_allowed?).to be false

        patient_mary.allow_phi!(file_name, t.full_description)

        expect(patient_mary.phi_allowed?).to be true
        expect(patient_mary.patient_detail.phi_allowed?).to be true
      end

      it 'does not extend to unextended association' do |t|
        expect(patient_mary.phi_allowed?).to be false
        expect(patient_mary.address.phi_allowed?).to be false

        patient_mary.allow_phi!(file_name, t.full_description)
        expect(patient_mary.phi_allowed?).to be true
        expect(patient_mary.address.phi_allowed?).to be false

        patient_mary.address.allow_phi!(file_name, t.full_description)
        expect(patient_mary.address.phi_allowed?).to be true
      end

      it 'extends access to :has_many associations' do |t|
        expect(patient_mary.health_records.first.phi_allowed?).to be false

        patient_mary.allow_phi!(file_name, t.full_description)
        expect(patient_mary.health_records.first.phi_allowed?).to be true
      end
    end

    context 'block access' do
      it 'extends access to extended association' do |t|
        expect(patient_mary.phi_allowed?).to be false
        expect(patient_mary.patient_detail.phi_allowed?).to be false

        patient_mary.allow_phi(file_name, t.full_description) do
          expect(patient_mary.phi_allowed?).to be true
          expect(patient_mary.patient_detail.phi_allowed?).to be true
        end
      end

      it 'does not extend to unextended association' do |t|
        expect(patient_mary.phi_allowed?).to be false
        expect(patient_mary.address.phi_allowed?).to be false

        patient_mary.allow_phi(file_name, t.full_description) do
          expect(patient_mary.phi_allowed?).to be true
          expect(patient_mary.address.phi_allowed?).to be false
        end

        patient_mary.address.allow_phi!(file_name, t.full_description)
        expect(patient_mary.address.phi_allowed?).to be true
      end

      it 'extends access to :has_many associations' do |t|
        expect(patient_mary.health_records.first.phi_allowed?).to be false

        patient_mary.allow_phi(file_name, t.full_description) do
          expect(patient_mary.health_records.first.phi_allowed?).to be true
        end
      end

      it 'revokes access after block' do |t|
        patient_mary.allow_phi(file_name, t.full_description) do
          expect(patient_mary.patient_detail.phi_allowed?).to be true
        end

        expect(patient_mary.phi_allowed?).to be false
        expect(patient_mary.patient_detail.phi_allowed?).to be false
        expect(patient_mary.health_records.first.phi_allowed?).to be false
      end

      it 'does not revoke access for untouched associations' do |t|
        # Here we extend access to two different associations.
        # When the block terminates, it should revoke (the one frame of) the `health_records` access,
        # but it should NOT revoke (the only frame of) the `patient_detail` access.
        # In either case, the "parent" object should still be able to re-extend access.

        patient_mary.allow_phi!(file_name, t.full_description)
        expect(patient_mary.patient_detail.phi_allowed?).to be true
        pd = patient_mary.patient_detail

        patient_mary.allow_phi(file_name, t.full_description) do
          expect(patient_mary.health_records.first.phi_allowed?).to be true
        end

        # The PatientInfo should re-extend access to `health_records`
        expect(patient_mary.health_records.first.phi_allowed?).to be true

        # We should still be able to access this through a different handle,
        # as the PatientDetail model should not have been affected by the end-of-block revocation.
        # The separate handle is important because this does not allow the access to
        # be quietly re-extended by the PatientInfo record.
        expect(pd.phi_allowed?).to be true
      end
    end
  end

  context 'nested allowances' do
    it 'retains outer access when disallowed at inner level' do |t|
      patient_with_detail.allow_phi(file_name, t.full_description) do
        expect(patient_with_detail.phi_allowed?).to be true

        patient_with_detail.allow_phi(file_name, t.full_description) do
          expect(patient_with_detail.phi_allowed?).to be true
        end # Inner permission revoked

        expect(patient_with_detail.phi_allowed?).to be true
        expect(patient_with_detail.patient_detail.phi_allowed?).to be true
      end # Outer permission revoked

      expect(patient_with_detail.phi_allowed?).to be false
      expect(patient_with_detail.patient_detail.phi_allowed?).to be false
    end
  end
end
