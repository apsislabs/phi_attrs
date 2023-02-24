# frozen_string_literal: true

# Namespace for classes and modules that handle PHI Attribute Access Logging
module PhiAttrs
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
      class_attribute :__phi_methods_to_extend

      after_initialize :wrap_phi

      # These have to default to an empty array
      self.__phi_methods_wrapped = []
      self.__phi_methods_to_extend = []
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
      def allow_phi!(user_id = nil, reason = nil)
        raise ArgumentError, 'block not allowed. use allow_phi with block' if block_given?

        user_id ||= current_user
        reason ||= i18n_reason
        raise ArgumentError, 'user_id and reason cannot be blank' if user_id.blank? || reason.blank?

        __phi_stack.push({
                           phi_access_allowed: true,
                           user_id: user_id,
                           reason: reason
                         })

        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info("PHI Access Enabled for '#{user_id}': #{reason}")
        end
      end

      # Enable PHI access for any instance of this class in the block given only.
      #
      # @param [String] user_id                       A unique identifier for the person accessing the PHI
      # @param [String] reason                        The reason for accessing PHI
      # @param [collection of PhiRecord] allow_only   Specific PhiRecords to allow access to
      # &block [block]                                The block in which PHI access is allowed for the class
      #
      # @example
      #   Foo.allow_phi('user@example.com', 'viewing patient record') do
      #     # PHI Access Allowed
      #   end
      #   # PHI Access Disallowed
      #
      # @example
      #   Foo.allow_phi('user@example.com', 'exporting patient list', allow_only: list_of_foos) do
      #     # PHI Access Allowed for `list_of_foo` only
      #   end
      #   # PHI Access Disallowed
      #
      def allow_phi(user_id = nil, reason = nil, allow_only: nil, &block)
        get_phi(user_id, reason, allow_only: allow_only, &block)
        return
      end

      # Enable PHI access for any instance of this class in the block given only
      # returning whatever the block returns.
      #
      # @param [String] user_id                       A unique identifier for the person accessing the PHI
      # @param [String] reason                        The reason for accessing PHI
      # @param [collection of PhiRecord] allow_only   Specific PhiRecords to allow access to
      # &block [block]                                The block in which PHI access is allowed for the class
      #
      # @example
      #   results = Foo.allow_phi('user@example.com', 'viewing patient record') do
      #     Foo.search(params)
      #   end
      #
      # @example
      #   loaded_foo = Foo.allow_phi('user@example.com', 'exporting patient list', allow_only: list_of_foos) do
      #     Bar.find_by(foo: list_of_foos).include(:foo)
      #   end
      #
      def get_phi(user_id = nil, reason = nil, allow_only: nil)
        raise ArgumentError, 'block required' unless block_given?

        if allow_only.present?
          raise ArgumentError, 'allow_only must be iterable with each' unless allow_only.respond_to?(:each)
          raise ArgumentError, "allow_only must all be `#{name}` objects" unless allow_only.all? { |t| t.is_a?(self) }
          raise ArgumentError, 'allow_only must all have `allow_phi!` methods' unless allow_only.all? { |t| t.respond_to?(:allow_phi!) }
        end

        # Save this so we don't revoke access previously extended outside the block
        frozen_instances = __instances_with_extended_phi.index_with { |obj| obj.instance_variable_get(:@__phi_relations_extended).clone }

        if allow_only.nil?
          allow_phi!(user_id, reason)
        else
          allow_only.each { |t| t.allow_phi!(user_id, reason) }
        end

        result = yield if block_given?

        __instances_with_extended_phi.each do |obj|
          if frozen_instances.include?(obj)
            old_extensions = frozen_instances[obj]
            new_extensions = obj.instance_variable_get(:@__phi_relations_extended) - old_extensions
            obj.send(:revoke_extended_phi!, new_extensions) if new_extensions.any?
          else
            obj.send(:revoke_extended_phi!) # Instance is new to the set, so revoke everything
          end
        end

        if allow_only.nil?
          disallow_last_phi!
        else
          allow_only.each { |t| t.disallow_last_phi!(preserve_extensions: true) }
          # We've handled any newly extended allowances ourselves above
        end

        result
      end

      # Explicitly disallow phi access in a specific area of code. This does not
      # play nicely with the mutating versions of `allow_phi!` and `disallow_phi!`
      #
      # At the moment, this doesn't work at all, as the instance won't
      # necessarily look at the class-level stack when determining if PHI is allowed.
      #
      # &block [block] The block in which PHI access is explicitly disallowed.
      #
      # @example
      #   # PHI Access Disallowed
      #   Foo.disallow_phi
      #     # PHI Access *Still* Disallowed
      #   end
      #   # PHI Access *Still, still* Disallowed
      #   Foo.allow_phi!('user@example.com', 'viewing patient record')
      #   # PHI Access Allowed
      #   Foo.disallow_phi do
      #     # PHI Access Disallowed
      #   end
      #   # PHI Access Allowed Again
      def disallow_phi
        raise ArgumentError, 'block required. use disallow_phi! without block' unless block_given?

        __phi_stack.push({
                           phi_access_allowed: false
                         })

        yield if block_given?

        __phi_stack.pop
      end

      # Revoke all PHI access for this class, if enabled by PhiRecord#allow_phi!
      #
      # @example
      #   Foo.disallow_phi!
      #
      def disallow_phi!
        raise ArgumentError, 'block not allowed. use disallow_phi with block' if block_given?

        message = __phi_stack.present? ? "PHI access disabled for #{__user_id_string(__phi_stack)}" : 'PHI access disabled. No class level access was granted.'

        __reset_phi_stack

        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info(message)
        end
      end

      # Revoke last PHI access for this class, if enabled by PhiRecord#allow_phi!
      #
      # @example
      #   Foo.disallow_last_phi!
      #
      def disallow_last_phi!
        raise ArgumentError, 'block not allowed' if block_given?

        removed_access = __phi_stack.pop
        message = removed_access.present? ? "PHI access disabled for #{removed_access[:user_id]}" : 'PHI access disabled. No class level access was granted.'

        PhiAttrs::Logger.tagged(PHI_ACCESS_LOG_TAG, name) do
          PhiAttrs::Logger.info(message)
        end
      end

      # Whether PHI access is allowed for this class
      #
      # @example
      #   Foo.phi_allowed?
      #
      # @return [Boolean] whether PHI access is allowed for this instance
      #
      def phi_allowed?
        __phi_stack.present? && __phi_stack[-1][:phi_access_allowed]
      end

      def __instances_with_extended_phi
        RequestStore.store[:phi_instances_with_extended_phi] ||= Set.new
      end

      def __phi_stack
        RequestStore.store[:phi_access] ||= {}
        RequestStore.store[:phi_access][name] ||= []
      end

      def __reset_phi_stack
        RequestStore.store[:phi_access] ||= {}
        RequestStore.store[:phi_access][name] = []
      end

      def __user_id_string(access_list)
        access_list ||= []
        access_list.map { |c| "'#{c[:user_id]}'" }.join(',')
      end

      def current_user
        RequestStore.store[:phi_attrs_current_user]
      end

      def i18n_reason
        controller = RequestStore.store[:phi_attrs_controller]
        action = RequestStore.store[:phi_attrs_action]

        return nil if controller.blank? || action.blank?

        i18n_path = [PhiAttrs.translation_prefix] + __path_to_controller_and_action(controller, action)
        i18n_path.push(*__path_to_class)
        i18n_key = i18n_path.join('.')

        return I18n.t(i18n_key) if I18n.exists?(i18n_key)

        locale = I18n.locale || I18n.default_locale

        PhiAttrs::Logger.warn "No #{locale} PHI Reason found for #{i18n_key}"
      end

      def __path_to_controller_and_action(controller, action)
        module_paths = controller.underscore.split('/')
        class_name_parts = module_paths.pop.split('_')
        class_name_parts.pop if class_name_parts[-1] == 'controller'
        module_paths.push(class_name_parts.join('_'), action)
      end

      def __path_to_class
        module_paths = name.underscore.split('/')
        class_name_parts = module_paths.pop.split('_')
        module_paths.push(class_name_parts.join('_'))
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
    def allow_phi!(user_id = nil, reason = nil)
      raise ArgumentError, 'block not allowed. use allow_phi with block' if block_given?

      user_id ||= self.class.current_user
      reason ||= self.class.i18n_reason
      raise ArgumentError, 'user_id and reason cannot be blank' if user_id.blank? || reason.blank?

      PhiAttrs::Logger.tagged(*phi_log_keys) do
        @__phi_access_stack.push({
                                   phi_access_allowed: true,
                                   user_id: user_id,
                                   reason: reason
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
    def allow_phi(user_id = nil, reason = nil, &block)
      get_phi(user_id, reason, &block)
      return
    end

    # Enable PHI access for a single instance of this class inside the block.
    # Returns whatever is returned from the block.
    # Nested calls to get_phi will log once per nested call
    # s
    # @param [String] user_id   A unique identifier for the person accessing the PHI
    # @param [String] reason    The reason for accessing PHI
    # @yield                    The block in which phi access is allowed
    #
    # @return PHI
    #
    # @example
    #   foo = Foo.find(1)
    #   phi_data = foo.get_phi('user@example.com', 'viewing patient record') do
    #    foo.phi_field
    #   end
    #
    def get_phi(user_id = nil, reason = nil)
      raise ArgumentError, 'block required' unless block_given?

      extended_instances = @__phi_relations_extended.clone
      allow_phi!(user_id, reason)

      result = yield if block_given?

      new_extensions = @__phi_relations_extended - extended_instances
      disallow_last_phi!(preserve_extensions: true)
      revoke_extended_phi!(new_extensions) if new_extensions.any?

      result
    end

    # Revoke all PHI access for a single instance of this class.
    #
    # @example
    #   foo = Foo.find(1)
    #   foo.disallow_phi!
    #
    def disallow_phi!
      raise ArgumentError, 'block not allowed. use disallow_phi with block' if block_given?

      PhiAttrs::Logger.tagged(*phi_log_keys) do
        removed_access_for = self.class.__user_id_string(@__phi_access_stack)

        revoke_extended_phi!
        @__phi_access_stack = []

        message = removed_access_for.present? ? "PHI access disabled for #{removed_access_for}" : 'PHI access disabled. No instance level access was granted.'
        PhiAttrs::Logger.info(message)
      end
    end

    # Dissables PHI access for a single instance of this class inside the block.
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
    def disallow_phi
      raise ArgumentError, 'block required. use disallow_phi! without block' unless block_given?

      add_disallow_flag!
      add_disallow_flag_to_extended_phi!

      yield if block_given?

      remove_disallow_flag_from_extended_phi!
      remove_disallow_flag!
    end

    # Revoke last PHI access for a single instance of this class.
    #
    # @example
    #   foo = Foo.find(1)
    #   foo.disallow_last_phi!
    #
    def disallow_last_phi!(preserve_extensions: false)
      raise ArgumentError, 'block not allowed' if block_given?

      PhiAttrs::Logger.tagged(*phi_log_keys) do
        removed_access = @__phi_access_stack.pop

        revoke_extended_phi! unless preserve_extensions
        message = removed_access.present? ? "PHI access disabled for #{removed_access[:user_id]}" : 'PHI access disabled. No instance level access was granted.'
        PhiAttrs::Logger.info(message)
      end
    end

    # The unique identifier for whom access has been allowed on this instance.
    # This is what was passed in when PhiRecord#allow_phi! was called.
    #
    # @return [String] the user_id passed in to allow_phi!
    #
    def phi_allowed_by
      phi_context[:user_id]
    end

    # The access reason for allowing access to this instance.
    # This is what was passed in when PhiRecord#allow_phi! was called.
    #
    # @return [String] the reason passed in to allow_phi!
    #
    def phi_access_reason
      phi_context[:reason]
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
      !phi_context.nil? && phi_context[:phi_access_allowed]
    end

    # Require phi access. Raises an error pre-emptively if it has not been granted.
    #
    # @example
    #   def use_phi(patient_record)
    #     patient_record.require_phi!
    #     # ...use PHI Freely
    #   end
    #
    def require_phi!
      raise PhiAccessException, 'PHI Access required, please call allow_phi or allow_phi! first' unless phi_allowed?
    end

    def reload
      @__phi_relations_extended.clear
      super
    end

    protected

    # Adds a disallow phi flag to instance internal stack.
    # @private since subject to change
    def add_disallow_flag!
      @__phi_access_stack.push({
                                 phi_access_allowed: false
                               })
    end

    # removes the last item in instance internal stack.
    # @private since subject to change
    def remove_disallow_flag!
      @__phi_access_stack.pop
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
      @__phi_methods_extended = Set.new
      @__phi_relations_extended = Set.new

      # Wrap attributes with PHI Logger and Access Control
      __phi_wrapped_methods.each { |m| phi_wrap_method(m) }
      __phi_extended_methods.each { |m| phi_wrap_extension(m) }
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

    def phi_context
      instance_phi_context || class_phi_context
    end

    def instance_phi_context
      @__phi_access_stack && @__phi_access_stack[-1]
    end

    def class_phi_context
      self.class.__phi_stack[-1]
    end

    # The unique identifiers for everything with access allowed on this instance.
    #
    # @private
    #
    # @return String of all the user_id's passed in to allow_phi!
    #
    def all_phi_allowed_by
      self.class.__user_id_string(all_phi_context)
    end

    def all_phi_context
      (@__phi_access_stack || []) + (self.class.__phi_stack || [])
    end

    def all_phi_context_logged?
      all_phi_context.all? { |v| v[:logged] }
    end

    def set_all_phi_context_logged
      all_phi_context.each { |c| c[:logged] = true }
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
      unless self.respond_to?(method_name)
        PhiAttrs::Logger.warn("#{self.class.name} tried to wrap non-existant method (#{method_name})")
        return
      end
      return if self.class.__phi_methods_wrapped.include? method_name

      wrapped_method = :"__#{method_name}_phi_wrapped"
      unwrapped_method = :"__#{method_name}_phi_unwrapped"

      self.class.send(:define_method, wrapped_method) do |*args, **kwargs, &block|
        PhiAttrs::Logger.tagged(*phi_log_keys) do
          unless phi_allowed?
            raise PhiAttrs::Exceptions::PhiAccessException, "Attempted PHI access for #{self.class.name} #{@__phi_user_id}"
          end

          unless all_phi_context_logged?
            PhiAttrs::Logger.info("#{self.class.name} access by [#{all_phi_allowed_by}]. Triggered by method: #{method_name}")
            set_all_phi_context_logged
          end

          send(unwrapped_method, *args, **kwargs, &block)
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
    def phi_wrap_extension(method_name)
      raise NameError, "Undefined relationship in `extend_phi_access`: #{method_name}" unless self.respond_to?(method_name)
      return if self.class.__phi_methods_to_extend.include? method_name

      wrapped_method = wrapped_extended_name(method_name)
      unwrapped_method = unwrapped_extended_name(method_name)

      self.class.send(:define_method, wrapped_method) do |*args, **kwargs, &block|
        relation = send(unwrapped_method, *args, **kwargs, &block)

        if phi_allowed? && (relation.present? && relation_klass(relation).included_modules.include?(PhiRecord))
          relations = relation.is_a?(Enumerable) ? relation : [relation]
          relations.each do |r|
            r.allow_phi!(phi_allowed_by, phi_access_reason) unless @__phi_relations_extended.include?(r)
          end
          @__phi_relations_extended.merge(relations)
          self.class.__instances_with_extended_phi.add(self)
        end

        relation
      end

      # method_name => wrapped_method => unwrapped_method
      self.class.send(:alias_method, unwrapped_method, method_name)
      self.class.send(:alias_method, method_name, wrapped_method)

      self.class.__phi_methods_to_extend << method_name
    end

    # Revoke PHI access for all `extend`ed relations (or only those given)
    def revoke_extended_phi!(relations = nil)
      relations ||= @__phi_relations_extended
      relations.each do |relation|
        relation.disallow_last_phi! if relation.present? && relation_klass(relation).included_modules.include?(PhiRecord)
      end
      @__phi_relations_extended.subtract(relations)
    end

    # Adds a disallow PHI access to the stack for block syntax for all `extend`ed relations (or only those given)
    def add_disallow_flag_to_extended_phi!(relations = nil)
      relations ||= @__phi_relations_extended
      relations.each do |relation|
        relation.add_disallow_flag! if relation.present? && relation_klass(relation).included_modules.include?(PhiRecord)
      end
    end

    # Adds a disallow PHI access to the stack for all for all `extend`ed relations (or only those given)
    def remove_disallow_flag_from_extended_phi!(relations = nil)
      relations ||= @__phi_relations_extended
      relations.each do |relation|
        relation.remove_disallow_flag! if relation.present? && relation_klass(relation).included_modules.include?(PhiRecord)
      end
    end

    def relation_klass(rel)
      return rel.klass if rel.is_a?(ActiveRecord::Relation)
      return rel.first.class if rel.is_a?(Enumerable)

      return rel.class
    end

    def wrapped_extended_name(method_name)
      :"__#{method_name}_phi_access_extended"
    end

    def unwrapped_extended_name(method_name)
      :"__#{method_name}_phi_access_original"
    end
  end
end
