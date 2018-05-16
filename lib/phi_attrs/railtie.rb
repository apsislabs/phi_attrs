require 'phi_attrs'
require 'rails'

module PhiAttrs
  class Railtie < Rails::Railtie
    initializer 'rolify.initialize' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send :extend, PhiAttrs
      end
    end
  end
end
