# frozen_string_literal: true

RSpec.describe 'class allow_phi' do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: 'Jane') }
  let(:patient_detail) { build(:patient_detail) }
  let(:patient_with_detail) { build(:patient_info, first_name: 'Jack', patient_detail: patient_detail) }

  context 'authorized' do
    it 'allows access to any instance' do |t|
      expect { patient_jane.first_name }.to raise_error(access_error)
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { patient_jane.first_name }.not_to raise_error
      end

      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { patient_jane.first_name }.not_to raise_error
    end

    it 'only allows access to the authorized class' do |t|
      expect { patient_detail.detail }.to raise_error(access_error)
      expect { patient_jane.first_name }.to raise_error(access_error)

      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { patient_jane.first_name }.not_to raise_error
        expect { patient_detail.detail }.to raise_error(access_error)
      end

      expect { patient_detail.detail }.to raise_error(access_error)
      expect { patient_jane.first_name }.to raise_error(access_error)

      PatientInfo.allow_phi!(file_name, t.full_description)

      expect { patient_jane.first_name }.not_to raise_error
      expect { patient_detail.detail }.to raise_error(access_error)
    end

    it 'revokes access after calling disallow_phi!' do |t|
      expect { patient_jane.first_name }.to raise_error(access_error)

      PatientInfo.allow_phi!(file_name, t.full_description)

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

    it 'allow_phi persists after a reload' do |t|
      dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail))
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { dumbledore.first_name }.not_to raise_error
        dumbledore.reload
        expect { dumbledore.first_name }.not_to raise_error
      end
    end

    it 'allow_phi persists extended phi after a reload' do |t|
      dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail, :all_random))
      expect { dumbledore.patient_detail.detail }.to raise_error(access_error)

      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { dumbledore.patient_detail.detail }.not_to raise_error
        dumbledore.reload
        expect { dumbledore.patient_detail.detail }.not_to raise_error
      end

      expect { dumbledore.patient_detail.detail }.to raise_error(access_error)
    end

    it 'allow_phi persists extended phi after a reload _and_ respects previous data' do |t|
      dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail, :all_random))
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { dumbledore.patient_detail.detail }.not_to raise_error

      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { dumbledore.patient_detail.detail }.not_to raise_error
        dumbledore.reload
        expect { dumbledore.patient_detail.detail }.not_to raise_error
      end

      expect { dumbledore.patient_detail.detail }.not_to raise_error
    end

    it 'allow_phi! persists after a reload' do |t|
      dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail))
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { dumbledore.first_name }.not_to raise_error
      dumbledore.reload
      expect { dumbledore.first_name }.not_to raise_error
    end

    it 'allow_phi! persists extended phi after a reload' do |t|
      dumbledore = create(:patient_info, first_name: 'Albus', patient_detail: build(:patient_detail, :all_random))
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { dumbledore.patient_detail.detail }.not_to raise_error
      dumbledore.reload
      expect { dumbledore.patient_detail.detail }.not_to raise_error
    end

    it 'get_phi with block returns value' do |t|
      expect(PatientInfo.get_phi(file_name, t.full_description) { patient_jane.first_name }).to eq('Jane')
    end

    it 'allow_phi with block returns value' do |t|
      result = PatientInfo.allow_phi(file_name, t.full_description) do
        patient_jane.first_name
      end

      expect(result).not_to be_nil
      expect(result).to eq('Jane')
    end
  end

  context 'extended authorization' do
    let(:patient_mary) { create(:patient_info, :with_multiple_health_records) }

    it 'extends access to associations' do |t|
      expect { patient_mary.patient_detail.detail }.to raise_error(access_error)

      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { patient_mary.patient_detail.detail }.not_to raise_error
    end

    it 'extends access with a block' do |t|
      expect { patient_mary.patient_detail.detail }.to raise_error(access_error)

      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { patient_mary.patient_detail.detail }.not_to raise_error
      end

      expect { patient_mary.patient_detail.detail }.to raise_error(access_error)
    end

    it 'does not revoke access for untouched associations' do |t|
      # Here we extend access to two different associations.
      # When the block terminates, it should revoke (the one frame of) the `health_records` access,
      # but it should NOT revoke (the only frame of) the `patient_detail` access.
      # In either case, the "parent" object should still be able to re-extend access.

      PatientInfo.allow_phi!(file_name, t.full_description)
      expect { patient_mary.patient_detail.detail }.not_to raise_error
      pd = patient_mary.patient_detail

      PatientInfo.allow_phi(file_name, t.full_description) do
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

  context 'nested allowances' do
    it 'retains outer access when disallowed at inner level' do |t|
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect { patient_with_detail.first_name }.not_to raise_error

        PatientInfo.allow_phi(file_name, t.full_description) do
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
        expect { PatientInfo.allow_phi!('ok', 'ok') }.not_to raise_error
      end
      it 'raises ArgumentError with block' do
        expect { PatientInfo.allow_phi!('ok', 'ok') {} }.to raise_error(ArgumentError)
      end
    end

    context 'allow_phi!' do
      it 'succeeds' do
        expect { PatientInfo.allow_phi('ok', 'ok') {} }.not_to raise_error
      end
      it 'raises ArgumentError for allow_phi! without block' do
        expect { PatientInfo.allow_phi('ok', 'ok') }.to raise_error(ArgumentError)
      end
    end
  end
end
