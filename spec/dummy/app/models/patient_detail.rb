# frozen_string_literal: true

class PatientDetail < ApplicationRecord
  belongs_to :patient_info
  phi_model
end
