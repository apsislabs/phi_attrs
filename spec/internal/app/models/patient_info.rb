class PatientInfo < ActiveRecord::Base
  phi_model

  exclude_from_phi :last_name
  include_in_phi :birthday

  def birthday
    Time.current
  end
end
