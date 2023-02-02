# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :patient_info
  phi_model

  def inlined(avoid_phi: false)
    avoid_phi || address
  end
end
