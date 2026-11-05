# frozen_string_literal: true

require "spec_helper"

RSpec.describe "concurrent PHI method wrapping" do
  file_name = __FILE__

  # A fresh class for each example, so no methods are wrapped before the
  # threads start.
  def phi_model_class
    Class.new(ApplicationRecord) do
      def self.name = "ConcurrentWrapPatientInfo"

      self.table_name = "patient_infos"
      has_one :patient_detail, class_name: "PatientDetail", foreign_key: "patient_info_id"

      phi_model

      extend_phi_access :patient_detail
    end
  end

  # Stops the first thread just before it aliases the original method, after
  # the gem has checked that the alias does not exist yet. A second thread then
  # wraps the whole class. Without a lock, the first thread resumes and aliases
  # the original name to the method that is already wrapped. With a lock, the
  # second thread cannot finish, so the first thread resumes on the timeout.
  def instantiate_with_interleaving(klass, alias_suffix)
    first_arrived = Queue.new
    second_done = Queue.new
    claim = Mutex.new
    claimed = false

    klass.singleton_class.prepend(
      Module.new do
        define_method(:alias_method) do |new_name, old_name|
          if new_name.end_with?(alias_suffix)
            first = claim.synchronize { !claimed && (claimed = true) }
            if first
              first_arrived << true
              second_done.pop(timeout: 0.5)
            end
          end
          super(new_name, old_name)
        end
      end
    )

    first = Thread.new { klass.new }
    first_arrived.pop
    second =
      Thread.new do
        klass.new
      ensure
        second_done << true
      end
    [first, second].each(&:join)
  end

  def self_referencing_aliases(klass, methods, unwrapped_name, wrapped_name)
    methods.uniq.select do |method_name|
      klass.instance_method(unwrapped_name.call(method_name)) == klass.instance_method(wrapped_name.call(method_name))
    end
  end

  it "keeps attribute aliases pointing at the original methods" do |t|
    klass = phi_model_class
    klass.columns

    instantiate_with_interleaving(klass, "_phi_unwrapped")

    corrupted =
      self_referencing_aliases(
        klass,
        klass.__phi_methods_wrapped,
        ->(name) { :"__#{name}_phi_unwrapped" },
        ->(name) { :"__#{name}_phi_wrapped" }
      )
    expect(corrupted).to be_empty

    record = klass.new(first_name: "Jane")
    record.allow_phi!(file_name, t.full_description)
    expect(record.first_name).to eq("Jane")
  end

  it "keeps extended relation aliases pointing at the original methods" do |t|
    klass = phi_model_class
    klass.columns

    instantiate_with_interleaving(klass, "_phi_access_original")

    corrupted =
      self_referencing_aliases(
        klass,
        klass.__phi_methods_to_extend,
        ->(name) { :"__#{name}_phi_access_original" },
        ->(name) { :"__#{name}_phi_access_extended" }
      )
    expect(corrupted).to be_empty

    record = klass.new
    record.allow_phi!(file_name, t.full_description)
    expect(record.patient_detail).to be_nil
  end
end
