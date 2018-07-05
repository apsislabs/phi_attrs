class PatientInfo < ActiveRecord::Base
  has_one :patient_detail, inverse_of: 'patient_info'
  has_one :address, inverse_of: 'patient_info'

  phi_model

  extend_phi_access :patient_detail

  exclude_from_phi :last_name
  include_in_phi :birthday

  def birthday
    Time.current
  end
end
