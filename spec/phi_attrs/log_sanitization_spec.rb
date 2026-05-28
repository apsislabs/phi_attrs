# frozen_string_literal: true

require "spec_helper"

RSpec.describe "log sanitization" do
  let(:patient_jane) { create(:patient_info, first_name: "Jane") }

  it "strips newlines from user_id" do
    patient_jane.allow_phi!("user\nINJECTED", "reason")
    expect(patient_jane.phi_allowed_by).to eq("user INJECTED")
  end

  it "strips newlines from reason" do
    patient_jane.allow_phi!("user", "reason\r\nINJECTED")
    expect(patient_jane.phi_access_reason).to eq("reason  INJECTED")
  end

  it "strips newlines from class-level allow" do
    PatientInfo.allow_phi!("user\nINJECTED", "reason\nINJECTED")
    expect(PatientInfo.__phi_stack.last.user_id).to eq("user INJECTED")
    expect(PatientInfo.__phi_stack.last.reason).to eq("reason INJECTED")
  end
end
