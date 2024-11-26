# frozen_string_literal: true

class MissingAttributeModel < ApplicationRecord
  phi_model
  include_in_phi :non_existent_method
end
