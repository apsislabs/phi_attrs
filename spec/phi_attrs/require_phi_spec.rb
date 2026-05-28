# frozen_string_literal: true

require "spec_helper"

RSpec.describe "require_phi!" do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: "Jane") }

  it "raises PhiAccessException when no access granted" do
    expect { patient_jane.require_phi! }.to raise_error(access_error)
  end

  it "does not raise when instance access granted" do |t|
    patient_jane.allow_phi!(file_name, t.full_description)
    expect { patient_jane.require_phi! }.not_to raise_error
  end

  it "does not raise when class access granted" do |t|
    PatientInfo.allow_phi!(file_name, t.full_description)
    expect { patient_jane.require_phi! }.not_to raise_error
  end
end
