class HealthRecord < ActiveRecord::Base
  belongs_to :patient_info
  phi_model
end
