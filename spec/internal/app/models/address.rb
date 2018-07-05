class Address < ActiveRecord::Base
  belongs_to :patient_info
  phi_model
end
