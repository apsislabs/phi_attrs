# frozen_string_literal: true

require 'rails'
require 'active_support'
require 'request_store'
require 'securerandom'

require 'phi_attrs/version'
require 'phi_attrs/configure'
require 'phi_attrs/railtie' if defined?(Rails)
require 'phi_attrs/formatter'
require 'phi_attrs/logger'
require 'phi_attrs/exceptions'
require 'phi_attrs/phi_record'

module PhiAttrs
  def self.log_phi_access(user, message)
    PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, user) do
      PhiAttrs::Logger.info(message)
    end
  end

  module Model
    def phi_model(with: nil, except: nil)
      include PhiRecord
    end
  end

  module Controller
    extend ActiveSupport::Concern

    included do
      before_action :record_i18n_data
    end

    private

    def record_i18n_data
      RequestStore.store[:phi_attrs_controller] = self.class.name
      RequestStore.store[:phi_attrs_action] = params[:action]

      return if PhiAttrs.current_user_method.nil?
      return unless respond_to?(PhiAttrs.current_user_method, true)

      RequestStore.store[:phi_attrs_current_user] = send(PhiAttrs.current_user_method)
    end
  end
end
