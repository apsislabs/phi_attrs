# frozen_string_literal: true

require "spec_helper"

# PHI_WRAP_LOCK is a Monitor rather than a Mutex. These specs show why (the
# thread holding the lock can take it again) and check that the Monitor has no
# side effects: no deadlocks, no corrupted aliases, the lock is released on
# error, and it is not taken once a class is wrapped.
RSpec.describe "PHI wrap lock" do
  let(:file_name) { __FILE__ }

  def phi_model_class(name = "WrapLockPatientInfo")
    Class.new(ApplicationRecord) do
      define_singleton_method(:name) { name }

      self.table_name = "patient_infos"
      has_one :patient_detail, class_name: "PatientDetail", foreign_key: "patient_info_id"

      phi_model

      extend_phi_access :patient_detail
    end.tap(&:columns)
  end

  # Runs the block the first time the gem defines a wrapper method on `klass`.
  # `method_added` fires while the gem holds PHI_WRAP_LOCK, so the block runs
  # inside the lock.
  def on_first_wrapper_defined(klass, &hook)
    fired = false
    klass.singleton_class.prepend(
      Module.new do
        define_method(:method_added) do |name|
          super(name)
          if !fired && name.to_s.end_with?("_phi_wrapped")
            fired = true
            hook.call
          end
        end
      end
    )
  end

  def self_referencing_aliases(klass)
    attributes = klass.__phi_methods_wrapped.uniq.select do |m|
      klass.instance_method(:"__#{m}_phi_unwrapped") == klass.instance_method(:"__#{m}_phi_wrapped")
    end
    relations = klass.__phi_methods_to_extend.uniq.select do |m|
      klass.instance_method(:"__#{m}_phi_access_original") == klass.instance_method(:"__#{m}_phi_access_extended")
    end
    attributes + relations
  end

  def expect_phi_wrapped(klass, reason)
    expect(self_referencing_aliases(klass)).to be_empty

    # New records are always allowed, so check a saved one.
    record = klass.find(klass.create!(first_name: "Jane").id)
    expect { record.first_name }.to raise_error(access_error)

    record.allow_phi!(file_name, reason)
    expect(record.first_name).to eq("Jane")
    expect(record.patient_detail).to be_nil
  end

  it "is a Monitor" do
    expect(PhiAttrs::PhiRecord::PHI_WRAP_LOCK).to be_a(Monitor)
  end

  context "when the thread holding the lock builds another PHI record" do
    it "wraps both models when the nested record is a different model" do |t|
      outer = phi_model_class("WrapLockOuter")
      inner = phi_model_class("WrapLockInner")
      on_first_wrapper_defined(outer) { inner.new }

      expect { outer.new }.not_to raise_error

      expect_phi_wrapped(outer, t.full_description)
      expect_phi_wrapped(inner, t.full_description)
    end

    it "wraps the model once when the nested record is the same model" do |t|
      klass = phi_model_class
      on_first_wrapper_defined(klass) { klass.new }

      expect { klass.new }.not_to raise_error

      expect_phi_wrapped(klass, t.full_description)
    end

    it "would raise with a Mutex, which cannot be locked again by its owner" do
      stub_const("PhiAttrs::PhiRecord::PHI_WRAP_LOCK", Mutex.new)
      outer = phi_model_class("WrapLockOuter")
      inner = phi_model_class("WrapLockInner")
      on_first_wrapper_defined(outer) { inner.new }

      expect { outer.new }.to raise_error(ThreadError, /deadlock; recursive locking/)
    end
  end

  it "releases the lock when wrapping raises" do |t|
    klass = phi_model_class
    on_first_wrapper_defined(klass) { raise "boom" }

    expect { klass.new }.to raise_error(RuntimeError, "boom")
    expect(PhiAttrs::PhiRecord::PHI_WRAP_LOCK.mon_locked?).to be(false)

    # Another thread can take the lock and finish wrapping the class.
    thread = Thread.new { klass.new }
    expect(thread.join(5)).to eq(thread)

    expect_phi_wrapped(klass, t.full_description)
  end

  it "does not take the lock once the class is wrapped" do
    klass = phi_model_class
    klass.new

    allow(PhiAttrs::PhiRecord::PHI_WRAP_LOCK).to receive(:synchronize).and_call_original
    klass.new

    expect(PhiAttrs::PhiRecord::PHI_WRAP_LOCK).not_to have_received(:synchronize)
  end

  it "does not deadlock or corrupt aliases when many threads wrap several models" do |t|
    klasses = Array.new(4) { |i| phi_model_class("WrapLockModel#{i}") }
    start = Queue.new

    threads = Array.new(8) do
      Thread.new do
        start.pop
        klasses.shuffle.each(&:new)
      end
    end
    threads.size.times { start << true }

    finished = threads.map { |thread| thread.join(10) }
    expect(finished).to all(be_a(Thread))

    klasses.each { |klass| expect_phi_wrapped(klass, t.full_description) }
  end
end
