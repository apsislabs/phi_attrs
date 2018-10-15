# frozen_string_literal: true

require 'phi_attrs'
require 'rails'

module PhiAttrs
  class Railtie < Rails::Railtie
    initializer 'phi_attrs.initialize' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send :extend, PhiAttrs
      end
    end
  end
end
