# Namespace for classes and modules that handle PHI Attribute Access Logging
module PhiAttrs
  PHI_ACCESS_LOG_TAG = 'PHI Access Log'.freeze

  # Module for extending ActiveRecord models to handle PHI access logging
  # and restrict access to attributes.
  #
  # @author Apsis Labs
  # @since 0.1.0
  module PhiRecord
    extend ActiveSupport::Concern

    included do
      class_attribute :__phi_exclude_methods
      class_attribute :__phi_include_methods
      class_attribute :__phi_extend_methods
      class_attribute :__phi_methods_wrapped
      class_attribute :__phi_methods_extended

      after_initialize :wrap_phi

      # These have to default to an empty array
      self.__phi_methods_wrapped = []
      self.__phi_methods_extended = []
    end

    class_methods do
      # Set methods to be excluded from PHI access logging.
      #
      # @param [Array<Symbol>] *methods Any number of methods to exclude
      #
      # @example
      #   exclude_from_phi :foo, :bar
      #
      def exclude_from_phi(*methods)
        self.__phi_exclude_methods = methods.map(&:to_s)
      end

      # Set methods to be explicitly included in PHI access logging.
      #
      # @param [Array<Symbol>] *methods Any number of methods to include
      #
      # @example
      #   include_in_phi :foo, :bar
      #
      def include_in_phi(*methods)
        self.__phi_include_methods = methods.map(&:to_s)
      end

      # Set of methods which should be implicitly allowed if this object
      # is allowed. The methods that are extended should return ActiveRecord
      # models that also extend PhiAttrs.
      #
      # @param [Array<Symbol>] *methods Any number of methods to extend access to
      #
      # @example
      #   has_one :foo
      #   has_one :bar
      #   extend_phi_access :foo, :bar
      #
      def extend_phi_access(*methods)
        self.__phi_extend_methods = methods.map(&:to_s)
      end

      # Enable PHI access for any instance of this class.
      #
      # @param [String] user_id   A unique identifier for the person accessing the PHI
      # @param [String] reason    The reason for accessing PHI
      #
      # @example
      #   Foo.allow_phi!('user@example.com', 'viewing patient record')
      #
      def allow_phi!(user_id, reason)
        self.__phi_stack.push({
          phi_access_allowed: true,
          user_id: user_id,
          reason: reason
        })

        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info("PHI Access Enabled for #{user_id}: #{reason}")
        end
      end

      # Enable PHI access for any instance of this class in the block given only.
      #
      # @param [String] user_id   A unique identifier for the person accessing the PHI
      # @param [String] reason    The reason for accessing PHI
      # &block [block]            The block in which PHI access is allowed for the class
      #
      # @example
      #   Foo.allow_phi('user@example.com', 'viewing patient record') do
      #     # PHI Access Allowed
      #   end
      #   # PHI Access Disallowed
      #
      def allow_phi(user_id, reason)
        allow_phi!(user_id, reason)

        yield if block_given?

        disallow_phi!
      end

      # Explicitly disallow phi access in a specific area of code. This does not
      # play nicely with the mutating versions of `allow_phi!` and `disallow_phi!`
      #
      # &block [block] The block in which PHI access is explicitly disallowed.
      #
      # @example
      # # PHI Access Disallowed
      # Foo.disallow_phi
      #   # PHI Access *Still* Disallowed
      # end
      # # PHI Access *Still, still* Disallowed
      # Foo.allow_phi!('user@example.com', 'viewing patient record')
      # # PHI Access Allowed
      # Foo.disallow_phi do
      #   # PHI Access Disallowed
      # end
      # # PHI Access Allowed Again
      def disallow_phi
        __phi_stack.push({
          phi_access_allowed: false
        })

        yield if block_given?

        __phi_stack.pop
      end

      # Revoke PHI access for this class, if enabled by PhiRecord#allow_phi!
      #
      # @example
      #   Foo.disallow_phi!
      #
      def disallow_phi!
        __phi_stack.pop
        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info('PHI access disabled')
        end
      end

      def __phi_stack
        RequestStore.store[:phi_access] ||= {}
        RequestStore.store[:phi_access][name] ||= []
      end
    end

    # Get all method names to be wrapped with PHI access logging
    #
    # @return [Array<String>] the method names to be wrapped with PHI access logging
    #
    def __phi_wrapped_methods
      excluded_methods = self.class.__phi_exclude_methods.to_a
      included_methods = self.class.__phi_include_methods.to_a

      attribute_names - excluded_methods + included_methods - [self.class.primary_key]
    end

    # Get all method names to be wrapped with PHI access extension
    #
    # @return [Array<String>] the method names to be wrapped with PHI access extension
    #
    def __phi_extended_methods
      self.class.__phi_extend_methods.to_a
    end

    # Enable PHI access for a single instance of this class.
    #
    # @param [String] user_id   A unique identifier for the person accessing the PHI
    # @param [String] reason    The reason for accessing PHI
    #
    # @example
    #   foo = Foo.find(1)
    #   foo.allow_phi!('user@example.com', 'viewing patient record')
    #
    def allow_phi!(user_id, reason)
      PhiAttrs::Logger.tagged(*phi_log_keys) do
        @__phi_access_stack.push({
          phi_access_allowed: true,
          user_id: user_id,
          access_reason: reason,
        })

        PhiAttrs::Logger.info("PHI Access Enabled for '#{user_id}': #{reason}")
      end
    end


    # Enable PHI access for a single instance of this class inside the block.
    # Nested calls to allow_phi will log once per nested call
    #
    # @param [String] user_id   A unique identifier for the person accessing the PHI
    # @param [String] reason    The reason for accessing PHI
    # @yield                    The block in which phi access is allowed
    #
    # @example
    #   foo = Foo.find(1)
    #   foo.allow_phi('user@example.com', 'viewing patient record') do
    #    # PHI Access Allowed Here
    #   end
    #   # PHI Access Disallowed Here
    #
    def allow_phi(user_id, reason)
      allow_phi!(user_id, reason)

      yield if block_given?

      disallow_phi!
    end

    # Revoke PHI access for a single instance of this class.
    #
    # @yield   The block in which phi access is explicitly disallowed
    #
    # @example
    #   foo = Foo.find(1)
    #   foo.disallow_phi!
    #
    def disallow_phi!
      PhiAttrs::Logger.tagged(*phi_log_keys) do
        @__phi_access_stack.pop

        PhiAttrs::Logger.info('PHI access disabled')
      end
    end

    # Whether PHI access is allowed for a single instance of this class
    #
    # @example
    #   foo = Foo.find(1)
    #   foo.phi_allowed?
    #
    # @return [Boolean] whether PHI access is allowed for this instance
    #
    def phi_allowed?
      phi_context != nil && phi_context[:phi_access_allowed]
    end

    private

    # Entry point for wrapping methods with PHI access logging. This is called
    # by an `after_initialize` hook from ActiveRecord.
    #
    # @private
    #
    def wrap_phi
      # Disable PHI access by default
      @__phi_access_stack = []

      # Wrap attributes with PHI Logger and Access Control
      __phi_wrapped_methods.each { |m| phi_wrap_method(m) }
      __phi_extended_methods.each { |m| phi_extend_access(m) }
    end

    # Log Key for an instance of this class. If the instance is persisted in the
    # database, then it is the primary key; otherwise it is the Ruby object_id
    # in memory.
    #
    # This is used by the tagged logger for tagging all log entries to find
    # the underlying model.
    #
    # @private
    #
    # @return [Array<String>] log key for an instance of this class
    #
    def phi_log_keys
      @__phi_log_id = persisted? ? "Key: #{attributes[self.class.primary_key]}" : "Object: #{object_id}"
      @__phi_log_keys = [PHI_ACCESS_LOG_TAG, self.class.name, @__phi_log_id]
    end

    # The unique identifier for whom access has been allowed on this instance.
    # This is what was passed in when PhiRecord#allow_phi! was called.
    #
    # @private
    #
    # @return [String] the user_id passed in to allow_phi!
    #
    def phi_allowed_by
      phi_context[:user_id]
    end

    # The access reason for allowing access to this instance.
    # This is what was passed in when PhiRecord#allow_phi! was called.
    #
    # @private
    #
    # @return [String] the reason passed in to allow_phi!
    #
    def phi_access_reason
      phi_context[:reason]
    end

    def phi_context
      instance_phi_context || class_phi_context
    end

    def instance_phi_context
      @__phi_access_stack && @__phi_access_stack[-1]
    end

    def class_phi_context
      self.class.__phi_stack[-1]
    end

    # Core logic for wrapping methods in PHI access logging and access restriction.
    #
    # This method takes a single method name, and creates a new method using
    # define_method; once this method is defined, the original method name
    # is aliased to the new method, and the original method is renamed to a
    # known key.
    #
    # @private
    #
    # @example
    #   Foo::phi_wrap_method(:bar)
    #
    #   foo = Foo.find(1)
    #   foo.bar # => raises PHI Access Exception
    #
    #   foo.allow_phi!('user@example.com', 'testing')
    #
    #   foo.bar # => returns original value of Foo#bar
    #
    #   # defines two new methods:
    #   #   __bar_phi_wrapped
    #   #   __bar_phi_unwrapped
    #   #
    #   # After these methods are defined
    #   # an alias chain is created that
    #   # roughly maps:
    #   #
    #   # bar => __bar_phi_wrapped => __bar_phi_unwrapped
    #   #
    #   # This ensures that all calls to Foo#bar pass
    #   # through access logging.
    #
    def phi_wrap_method(method_name)
      return if self.class.__phi_methods_wrapped.include? method_name

      wrapped_method = :"__#{method_name}_phi_wrapped"
      unwrapped_method = :"__#{method_name}_phi_unwrapped"

      self.class.send(:define_method, wrapped_method) do |*args, &block|
        PhiAttrs::Logger.tagged(*phi_log_keys) do
          raise PhiAttrs::Exceptions::PhiAccessException, "Attempted PHI access for #{self.class.name} #{@__phi_user_id}" unless phi_allowed?

          unless phi_context[:logged]
            PhiAttrs::Logger.info("'#{phi_allowed_by}' accessing #{self.class.name}. Triggered by method: #{method_name}")
            phi_context[:logged] = true
          end

          send(unwrapped_method, *args, &block)
        end
      end

      # method_name => wrapped_method => unwrapped_method
      self.class.send(:alias_method, unwrapped_method, method_name)
      self.class.send(:alias_method, method_name, wrapped_method)

      self.class.__phi_methods_wrapped << method_name
    end

    # Core logic for wrapping methods in PHI access extensions. Almost
    # functionally equivalent to the phi_wrap_method call above,
    # this method doesn't add any logging or access restriction, but
    # simply proxies the PhiRecord#allow_phi! call.
    #
    # @private
    #
    def phi_extend_access(method_name)
      return if self.class.__phi_methods_extended.include? method_name

      wrapped_method = :"__#{method_name}_phi_access_extended"
      unwrapped_method = :"__#{method_name}_phi_access_original"

      self.class.send(:define_method, wrapped_method) do |*args, &block|
        # get the unwrapped relation
        relation = send(unwrapped_method, *args, &block)

        if phi_allowed? && relation.class.included_modules.include?(PhiRecord)
          relation.allow_phi!(phi_allowed_by, phi_access_reason) unless relation.phi_allowed?
        end

        relation
      end

      # method_name => wrapped_method => unwrapped_method
      self.class.send(:alias_method, unwrapped_method, method_name)
      self.class.send(:alias_method, method_name, wrapped_method)

      self.class.__phi_methods_extended << method_name
    end
  end
end
