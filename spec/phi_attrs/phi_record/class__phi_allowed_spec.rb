# frozen_string_literal: true

RSpec.describe 'class phi_allowed?' do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: 'Jane') }
  let(:patient_detail) { build(:patient_detail) }
  let(:patient_with_detail) { build(:patient_info, first_name: 'Jack', patient_detail: patient_detail) }

  context 'authorized' do
    it 'allows access to any instance' do |t|
      expect(patient_jane.phi_allowed?).to be false
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(patient_jane.phi_allowed?).to be true
      end
      expect(patient_jane.phi_allowed?).to be false
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect(patient_jane.phi_allowed?).to be true
    end

    it 'only allows for the authorized class' do |t|
      expect(patient_detail.phi_allowed?).to be false
      expect(patient_jane.phi_allowed?).to be false

      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(patient_detail.phi_allowed?).to be false
        expect(patient_jane.phi_allowed?).to be true
      end

      expect(patient_detail.phi_allowed?).to be false
      expect(patient_jane.phi_allowed?).to be false

      PatientInfo.allow_phi!(file_name, t.full_description)

      expect(patient_detail.phi_allowed?).to be false
      expect(patient_jane.phi_allowed?).to be true
    end

    it 'revokes access after calling disallow_phi!' do |t|
      expect(patient_jane.phi_allowed?).to be false

      PatientInfo.allow_phi!(file_name, t.full_description)

      expect(patient_jane.phi_allowed?).to be true

      PatientInfo.disallow_phi!

      expect(patient_jane.phi_allowed?).to be false
    end
  end

  context 'extended authorization' do
    let(:patient_mary) { create(:patient_info, :with_multiple_health_records) }

    it 'does not revoke access for untouched associations' do |t|
      # Here we extend access to two different associations.
      # When the block terminates, it should revoke (the one frame of) the `health_records` access,
      # but it should NOT revoke (the only frame of) the `patient_detail` access.
      # In either case, the "parent" object should still be able to re-extend access.

      PatientInfo.allow_phi!(file_name, t.full_description)
      expect(patient_mary.patient_detail.phi_allowed?).to be true

      pd = patient_mary.patient_detail

      PatientInfo.allow_phi(file_name, t.full_description) do
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

  context 'nested allowances' do
    it 'retains outer access when disallowed at inner level' do |t|
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(patient_with_detail.phi_allowed?).to be true

        PatientInfo.allow_phi(file_name, t.full_description) do
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
