# frozen_string_literal: true

class MissingExtendModel < ApplicationRecord
  phi_model
  extend_phi_access :non_existent_model
end
