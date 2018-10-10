# frozen_string_literal: true

class HealthRecord < ApplicationRecord
  belongs_to :patient_info
  phi_model
end
