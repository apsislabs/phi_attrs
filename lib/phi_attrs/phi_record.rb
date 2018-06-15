module PhiAttrs
  PHI_ACCESS_LOG_TAG = 'PHI Access Log'.freeze

  module PhiRecord
    extend ActiveSupport::Concern

    included do
      class_attribute :__phi_exclude_methods
      class_attribute :__phi_include_methods
      class_attribute :__phi_methods_wrapped

      self.__phi_methods_wrapped = []
    end

    class_methods do
      def exclude_from_phi(*methods)
        self.__phi_exclude_methods = methods.map(&:to_s)
      end

      def include_in_phi(*methods)
        self.__phi_include_methods = methods.map(&:to_s)
      end

      def allow_phi!(user_id, reason)
        RequestStore.store[:phi_access] ||= {}

        RequestStore.store[:phi_access][name] ||= {
          phi_access_allowed: true,
          user_id: user_id,
          reason: reason
        }
        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info("PHI Access Enabled for #{user_id}: #{reason}")
        end
      end

      def disallow_phi!
        RequestStore.store[:phi_access].delete(name) if RequestStore.store[:phi_access].present?
        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info('PHI access disabled')
        end
      end
    end

    def initialize(*args)
      super(*args)

      # Disable PHI access by default
      @__phi_access_allowed = false
      @__phi_access_logged = false

      # Wrap attributes with PHI Logger and Access Control
      __phi_wrapped_methods.each { |attr| phi_wrap_method(attr) }
    end

    def __phi_wrapped_methods
      attribute_names - self.class.__phi_exclude_methods.to_a + self.class.__phi_include_methods.to_a - [self.class.primary_key]
    end

    def allow_phi!(user_id, reason)
      PhiAttrs::Logger.tagged( *phi_log_keys ) do
        @__phi_access_allowed = true
        @__phi_user_id = user_id
        @__phi_access_reason = reason

        PhiAttrs::Logger.info("PHI Access Enabled for '#{user_id}': #{reason}")
      end
    end

    def disallow_phi!
      PhiAttrs::Logger.tagged(*phi_log_keys) do
        @__phi_access_allowed = false
        @__phi_user_id = nil
        @__phi_access_reason = nil

        PhiAttrs::Logger.info('PHI access disabled')
      end
    end

    def phi_allowed?
      @__phi_access_allowed || RequestStore.store.dig(:phi_access, self.class.name, :phi_access_allowed)
    end

    def phi_allowed_by
      @__phi_user_id || RequestStore.store.dig(:phi_access, self.class.name, :user_id)
    end

    def phi_access_reason
      @__phi_access_reason || RequestStore.store.dig(:phi_access, self.class.name, :reason)
    end

    private

    def phi_log_keys
      @__phi_log_id = persisted? ? "Key: #{attributes[self.class.primary_key]}" : "Object: #{object_id}"
      @__phi_log_keys = [PHI_ACCESS_LOG_TAG, self.class.name, @__phi_log_id]
    end

    def phi_wrap_method(method_name)
      return if self.class.__phi_methods_wrapped.include? method_name

      wrapped_method = :"__#{method_name}_phi_wrapped"
      unwrapped_method = :"__#{method_name}_phi_unwrapped"

      self.class.send(:define_method, wrapped_method) do |*args, &block|
        PhiAttrs::Logger.tagged(*phi_log_keys) do
          raise PhiAttrs::Exceptions::PhiAccessException, "Attempted PHI access for #{self.class.name} #{@__phi_user_id}" unless phi_allowed?

          unless @__phi_access_logged
            PhiAttrs::Logger.info("'#{phi_allowed_by}' accessing #{self.class.name}.\n\t access logging triggered by method: #{method_name}")
            @__phi_access_logged = true
          end

          send(unwrapped_method, *args, &block)
        end
      end

      # method_name => wrapped_method => unwrapped_method
      self.class.send(:alias_method, unwrapped_method, method_name)
      self.class.send(:alias_method, method_name, wrapped_method)

      self.class.__phi_methods_wrapped << method_name
    end
  end
end
