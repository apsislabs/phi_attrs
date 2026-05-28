# frozen_string_literal: true

require "spec_helper"

RSpec.describe "exception safety" do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: "Jane") }

  context "class-level disallow_phi block" do
    it "restores permission when block raises" do |t|
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect(PatientInfo.phi_allowed?).to be true

      expect do
        PatientInfo.disallow_phi do
          expect(PatientInfo.phi_allowed?).to be false
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(PatientInfo.phi_allowed?).to be true
    end
  end

  context "instance-level disallow_phi block" do
    it "restores permission when block raises" do |t|
      patient_jane.allow_phi!(file_name, t.full_description)
      expect(patient_jane.phi_allowed?).to be true

      expect do
        patient_jane.disallow_phi do
          expect(patient_jane.phi_allowed?).to be false
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(patient_jane.phi_allowed?).to be true
    end
  end

  context "class-level allow_phi block" do
    it "revokes access when block raises" do |t|
      expect(PatientInfo.phi_allowed?).to be false

      expect do
        PatientInfo.allow_phi(file_name, t.full_description) do
          expect(PatientInfo.phi_allowed?).to be true
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(PatientInfo.phi_allowed?).to be false
    end
  end

  context "instance-level allow_phi block" do
    it "revokes access when block raises" do |t|
      expect(patient_jane.phi_allowed?).to be false

      expect do
        patient_jane.allow_phi(file_name, t.full_description) do
          expect(patient_jane.phi_allowed?).to be true
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(patient_jane.phi_allowed?).to be false
    end
  end

  context "class-level get_phi block" do
    it "revokes access when block raises" do |t|
      expect(PatientInfo.phi_allowed?).to be false

      expect do
        PatientInfo.get_phi(file_name, t.full_description) do
          expect(PatientInfo.phi_allowed?).to be true
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(PatientInfo.phi_allowed?).to be false
    end
  end

  context "instance-level get_phi block" do
    it "revokes access when block raises" do |t|
      expect(patient_jane.phi_allowed?).to be false

      expect do
        patient_jane.get_phi(file_name, t.full_description) do
          expect(patient_jane.phi_allowed?).to be true
          raise "boom"
        end
      end.to raise_error(RuntimeError, "boom")

      expect(patient_jane.phi_allowed?).to be false
    end
  end
end
