# frozen_string_literal: true

require "spec_helper"
require "phi_attrs/rspec"

RSpec.describe "allow_phi_access matcher" do
  file_name = __FILE__
  let(:patient_jane) { build(:patient_info, first_name: "Jane") }

  context "positive match" do
    it "matches when phi access is allowed" do |t|
      patient_jane.allow_phi!(file_name, t.full_description)
      expect(patient_jane).to allow_phi_access
    end

    it "does not match when phi access is not allowed" do
      expect(patient_jane).not_to allow_phi_access
    end
  end

  context "allowed_by chain" do
    it "matches when user_id matches" do |t|
      patient_jane.allow_phi!(file_name, t.full_description)
      expect(patient_jane).to allow_phi_access.allowed_by(file_name)
    end

    it "fails when user_id differs" do |t|
      patient_jane.allow_phi!(file_name, t.full_description)
      matcher = allow_phi_access.allowed_by("wrong_user")
      expect(matcher.matches?(patient_jane)).to be false
    end
  end

  context "with_access_reason chain" do
    it "matches when reason matches" do
      patient_jane.allow_phi!("user", "the_reason")
      expect(patient_jane).to allow_phi_access.with_access_reason("the_reason")
    end

    it "fails when reason differs" do
      patient_jane.allow_phi!("user", "the_reason")
      matcher = allow_phi_access.with_access_reason("wrong_reason")
      expect(matcher.matches?(patient_jane)).to be false
    end
  end

  context "negated matcher" do
    it "raises ArgumentError when allowed_by specified" do
      expect do
        expect(patient_jane).not_to allow_phi_access.allowed_by("user")
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when with_access_reason specified" do
      expect do
        expect(patient_jane).not_to allow_phi_access.with_access_reason("reason")
      end.to raise_error(ArgumentError)
    end
  end
end
