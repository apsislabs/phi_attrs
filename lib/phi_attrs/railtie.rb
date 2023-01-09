# frozen_string_literal: true

require 'phi_attrs'
require 'rails'

module PhiAttrs
  class Railtie < Rails::Railtie
    initializer 'phi_attrs.initialize' do |_app|
      ActiveSupport.on_load(:active_record) do
        ActiveSupport.on_load(:active_record) { extend PhiAttrs::Model }
        ActiveSupport.on_load(:action_controller) { include PhiAttrs::Controller }
      end
    end
  end
end
