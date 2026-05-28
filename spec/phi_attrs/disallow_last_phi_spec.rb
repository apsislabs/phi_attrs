# frozen_string_literal: true

require "spec_helper"

RSpec.describe "class disallow_last_phi!" do
  let(:patient_jane) { build(:patient_info, first_name: "Jane") }

  it "pops only the most recent allow" do |t|
    PatientInfo.allow_phi!("first_user", t.full_description)
    PatientInfo.allow_phi!("second_user", t.full_description)
    expect(PatientInfo.phi_allowed?).to be true

    PatientInfo.disallow_last_phi!
    expect(PatientInfo.phi_allowed?).to be true

    PatientInfo.disallow_last_phi!
    expect(PatientInfo.phi_allowed?).to be false
  end

  it "logs gracefully on empty stack" do
    expect { PatientInfo.disallow_last_phi! }.not_to raise_error
  end
end
