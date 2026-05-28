# frozen_string_literal: true

require "spec_helper"

RSpec.describe "phi_allowed_by and phi_access_reason" do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: "Jane") }

  context "phi_allowed_by" do
    it "returns nil when no access granted" do
      expect(patient_jane.phi_allowed_by).to be_nil
    end

    it "returns user_id after allow_phi!" do
      patient_jane.allow_phi!("test_user", "test_reason")
      expect(patient_jane.phi_allowed_by).to eq("test_user")
    end

    it "returns most recent user_id with stacked allows" do
      patient_jane.allow_phi!("first_user", "first_reason")
      patient_jane.allow_phi!("second_user", "second_reason")
      expect(patient_jane.phi_allowed_by).to eq("second_user")
    end

    it "falls back to class-level user_id" do |t|
      PatientInfo.allow_phi!(file_name, t.full_description)
      expect(patient_jane.phi_allowed_by).to eq(file_name)
    end
  end

  context "phi_access_reason" do
    it "returns nil when no access granted" do
      expect(patient_jane.phi_access_reason).to be_nil
    end

    it "returns reason after allow_phi!" do
      patient_jane.allow_phi!("test_user", "test_reason")
      expect(patient_jane.phi_access_reason).to eq("test_reason")
    end

    it "returns most recent reason with stacked allows" do
      patient_jane.allow_phi!("user", "first_reason")
      patient_jane.allow_phi!("user", "second_reason")
      expect(patient_jane.phi_access_reason).to eq("second_reason")
    end
  end
end
