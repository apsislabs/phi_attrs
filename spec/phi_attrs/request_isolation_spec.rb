# frozen_string_literal: true

require "spec_helper"

RSpec.describe "request isolation" do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: "Jane") }

  it "class-level allow is not visible after RequestStore.clear!" do |t|
    PatientInfo.allow_phi!(file_name, t.full_description)
    expect(PatientInfo.phi_allowed?).to be true

    RequestStore.end!
    RequestStore.clear!
    RequestStore.begin!

    expect(PatientInfo.phi_allowed?).to be false
  end

  it "instance still sees its own stack after RequestStore.clear!" do |t|
    patient_jane.allow_phi!(file_name, t.full_description)
    expect(patient_jane.phi_allowed?).to be true

    RequestStore.end!
    RequestStore.clear!
    RequestStore.begin!

    expect(patient_jane.phi_allowed?).to be true
    expect(PatientInfo.phi_allowed?).to be false
  end

  it "class-level extended phi instances are cleared across requests" do |t|
    patient = create(:patient_info, :with_multiple_health_records)
    PatientInfo.allow_phi!(file_name, t.full_description)
    patient.patient_detail.detail

    RequestStore.end!
    RequestStore.clear!
    RequestStore.begin!

    expect(PatientInfo.__instances_with_extended_phi).to be_empty
  end
end
