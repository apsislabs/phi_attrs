# frozen_string_literal: true

class MissingAttributeModel < ApplicationRecord
  phi_model
  phi_include_methods :non_existent_method
end
