# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'class phi_allowed?' do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: 'Jane') }

  context 'authorized' do
    it 'works' do |t|
      expect(PatientInfo.phi_allowed?).to be false
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(PatientInfo.phi_allowed?).to be true
      end

      PatientInfo.allow_phi!(file_name, t.full_description)
      expect(PatientInfo.phi_allowed?).to be true
    end

    it 'only allows access to the authorized class' do |t|
      expect(PatientDetail.phi_allowed?).to be false

      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(PatientInfo.phi_allowed?).to be true
        expect(PatientDetail.phi_allowed?).to be false
      end

      expect(PatientDetail.phi_allowed?).to be false
      expect(PatientInfo.phi_allowed?).to be false

      PatientInfo.allow_phi!(file_name, t.full_description)

      expect(PatientInfo.phi_allowed?).to be true
      expect(PatientDetail.phi_allowed?).to be false
    end

    it 'revokes access after calling disallow_phi!' do |t|
      expect(PatientInfo.phi_allowed?).to be false

      PatientInfo.allow_phi!(file_name, t.full_description)

      expect(PatientInfo.phi_allowed?).to be true

      PatientInfo.disallow_phi!

      expect(PatientInfo.phi_allowed?).to be false
    end

    it 'revokes access for disallow_phi block' do |t|
      expect(PatientInfo.phi_allowed?).to be false

      PatientInfo.allow_phi!(file_name, t.full_description)

      expect(PatientInfo.phi_allowed?).to be true

      PatientInfo.disallow_phi do
        expect(PatientInfo.phi_allowed?).to be false
      end

      expect(PatientInfo.phi_allowed?).to be true
    end
  end

  context 'nested allowances' do
    it 'retains outer access when disallowed at inner level' do |t|
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(PatientInfo.phi_allowed?).to be true

        PatientInfo.allow_phi(file_name, t.full_description) do
          expect(PatientInfo.phi_allowed?).to be true
        end # Inner permission revoked

        expect(PatientInfo.phi_allowed?).to be true
      end # Outer permission revoked

      expect(PatientInfo.phi_allowed?).to be false
    end

    it 'retains outer access when disallow block at inner level' do |t|
      PatientInfo.allow_phi(file_name, t.full_description) do
        expect(PatientInfo.phi_allowed?).to be true

        PatientInfo.disallow_phi do
          expect(PatientInfo.phi_allowed?).to be false
        end # Inner disallow removed

        expect(PatientInfo.phi_allowed?).to be true
      end # Outer permission revoked

      expect(PatientInfo.phi_allowed?).to be false
    end

    it 'retains outer access with nested disallow blocks' do |t|
      PatientInfo.allow_phi!(file_name, t.full_description)

      PatientInfo.disallow_phi do
        expect(PatientInfo.phi_allowed?).to be false

        PatientInfo.disallow_phi do
          expect(PatientInfo.phi_allowed?).to be false
        end # Inner disallow removed

        expect(PatientInfo.phi_allowed?).to be false
      end # Outer disallow removed

      expect(PatientInfo.phi_allowed?).to be true
    end
  end

  context 'with instance' do
    it 'allow_phi does not change status' do |t|
      expect(PatientInfo.phi_allowed?).to be false
      patient_jane.allow_phi(file_name, t.full_description) do
        expect(PatientInfo.phi_allowed?).to be false
      end
    end

    it 'disallow_phi does not change status' do |t|
      expect(PatientInfo.phi_allowed?).to be false
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect(PatientInfo.phi_allowed?).to be true

      patient_jane.disallow_phi do
        expect(PatientInfo.phi_allowed?).to be true
      end
    end
  end
end
