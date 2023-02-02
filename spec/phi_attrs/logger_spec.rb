# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Logger do
  file_name = __FILE__

  let(:patient_jane) { build(:patient_info, first_name: 'Jane') }

  context 'log' do
    context 'error' do
      it 'when raising an exception' do
        message = 'my error message'
        expect(PhiAttrs::Logger.logger).to receive(:error).with(message)

        expect do
          raise PhiAttrs::Exceptions::PhiAccessException, message
        end.to raise_error(access_error)
      end

      it 'for unauthorized access' do
        expect(PhiAttrs::Logger.logger).to receive(:error)
        expect { patient_jane.birthday }.to raise_error(access_error)
      end
    end

    context 'info' do
      it 'when granting phi to instance' do |t|
        expect(PhiAttrs::Logger.logger).to receive(:info)
        patient_jane.allow_phi!(file_name, t.full_description)
      end

      it 'when granting phi to class' do |t|
        expect(PhiAttrs::Logger.logger).to receive(:info)
        PatientInfo.allow_phi!(file_name, t.full_description)
      end

      it 'when revokes phi to class, no current access' do
        expect(PhiAttrs::Logger.logger).to receive(:info).with(/No class level/)
        PatientInfo.disallow_phi!
      end

      it 'when revokes phi to instance, no current access' do
        expect(PhiAttrs::Logger.logger).to receive(:info).with(/No instance level/)
        patient_jane.disallow_phi!
      end

      it 'when revokes phi to class, with current access' do |t|
        PatientInfo.allow_phi!(file_name, t.full_description)
        expect(PhiAttrs::Logger.logger).to receive(:info).with(Regexp.new(file_name))
        PatientInfo.disallow_phi!
      end

      it 'when revokes phi to instance, with current access' do |t|
        patient_jane.allow_phi!(file_name, t.full_description)
        expect(PhiAttrs::Logger.logger).to receive(:info).with(Regexp.new(file_name))
        patient_jane.disallow_phi!
      end

      it 'when accessing method' do |t|
        PatientInfo.allow_phi!(file_name, t.full_description)
        expect(PhiAttrs::Logger.logger).to receive(:info)
        patient_jane.first_name
      end
    end

    context 'identifier' do
      context 'allowed' do
        it 'object_id for unpersisted' do |t|
          PatientInfo.allow_phi!(file_name, t.full_description)
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Object: #{patient_jane.object_id}").and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:info)
          patient_jane.first_name
        end

        it 'id for persisted' do |t|
          PatientInfo.allow_phi!(file_name, t.full_description)
          patient_jane.save
          expect(patient_jane.persisted?).to be true
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Key: #{patient_jane.id}").and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:info)
          patient_jane.first_name
        end
      end

      context 'unauthorized' do
        it 'object_id for unpersisted' do
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Object: #{patient_jane.object_id}").and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::Exceptions::PhiAccessException::TAG).and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:error)
          expect { patient_jane.first_name }.to raise_error(access_error)
        end

        it 'id for persisted' do
          patient_jane.save
          # expect(patient_jane.persisted?).to be true
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, PatientInfo.name, "Key: #{patient_jane.id}").and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::Exceptions::PhiAccessException::TAG).and_call_original
          expect(PhiAttrs::Logger.logger).to receive(:error)
          expect { patient_jane.first_name }.to raise_error(access_error)
        end
      end

      it 'user for manual' do
        user = 'Test User'
        message = 'Access Granted Message'
        expect(PhiAttrs::Logger.logger).to receive(:tagged).with(PhiAttrs::PHI_ACCESS_LOG_TAG, user).and_call_original
        expect(PhiAttrs::Logger.logger).to receive(:info).with(message)
        PhiAttrs.log_phi_access(user, message)
      end
    end

    context 'frequency' do
      it 'once when accessing multiple methods' do |t|
        PatientInfo.allow_phi!(file_name, t.full_description)
        expect(PhiAttrs::Logger.logger).to receive(:info)
        patient_jane.first_name
        patient_jane.birthday
      end

      it 'multiple times for nested allow_phi calls' do |t|
        expect(PhiAttrs::Logger.logger).to receive(:info).exactly(6)

        PatientInfo.allow_phi(file_name, t.full_description) do # Logged allowed
          patient_jane.first_name # Logged access
          PatientInfo.allow_phi(file_name, t.full_description) do # Logged allowed
            patient_jane.birthday # Logged Access
          end # Logged Disallowed
        end # Logged Disallowed
      end

      it 'multiple times for nested allows and disallows' do |t|
        PatientInfo.allow_phi!("#{file_name}1", t.full_description)
        PatientInfo.allow_phi!("#{file_name}2", t.full_description)
        PatientInfo.allow_phi!("#{file_name}3", t.full_description)

        expect(PhiAttrs::Logger.logger).to receive(:info).exactly(1).ordered
        patient_jane.first_name

        expect(PhiAttrs::Logger.logger).to receive(:info).exactly(1).ordered
        PatientInfo.disallow_last_phi!

        expect(PhiAttrs::Logger.logger).to receive(:info).exactly(0).ordered
        patient_jane.birthday # Not logged again
      end
    end

    context 'full stack' do
      let(:first_allow) { 'first@allow.com' }
      let(:second_allow) { 'second@allow.com' }
      let(:regexp) { Regexp.new("#{first_allow}.+#{second_allow}|#{second_allow}.+#{first_allow}") }

      context 'for multiple allows' do
        def test_logger
          expect(PhiAttrs::Logger.logger).to receive(:info).with(regexp)
          patient_jane.first_name
        end

        def expect_disallow_message(allowed)
          expect(PhiAttrs::Logger.logger).to receive(:info).with("PHI access disabled for #{allowed}")
        end

        context 'first class' do
          it 'then class' do |t|
            PatientInfo.allow_phi!(first_allow, t.full_description)
            PatientInfo.allow_phi!(second_allow, t.full_description)
            test_logger
          end

          it 'then instance' do |t|
            PatientInfo.allow_phi!(first_allow, t.full_description)
            patient_jane.allow_phi!(second_allow, t.full_description)
            test_logger
          end

          it 'then class block' do |t|
            PatientInfo.allow_phi!(first_allow, t.full_description)
            PatientInfo.allow_phi(second_allow, t.full_description) do
              test_logger
              expect_disallow_message(second_allow)
            end
          end

          it 'then instance block' do |t|
            PatientInfo.allow_phi!(first_allow, t.full_description)
            patient_jane.allow_phi(second_allow, t.full_description) do
              test_logger
              expect_disallow_message(second_allow)
            end
          end

          it 'only one when previously revoked' do |t|
            PatientInfo.allow_phi!(first_allow, t.full_description)
            PatientInfo.disallow_phi!
            patient_jane.allow_phi!(second_allow, t.full_description)
            expect(PhiAttrs::Logger.logger).to receive(:info).with(Regexp.new(second_allow))
            patient_jane.first_name
          end
        end

        context 'first instance' do
          it 'then class' do |t|
            patient_jane.allow_phi!(first_allow, t.full_description)
            PatientInfo.allow_phi!(second_allow, t.full_description)
            test_logger
          end

          it 'then instance' do |t|
            patient_jane.allow_phi!(first_allow, t.full_description)
            patient_jane.allow_phi!(second_allow, t.full_description)
            test_logger
          end

          it 'then class block' do |t|
            patient_jane.allow_phi!(first_allow, t.full_description)
            PatientInfo.allow_phi(second_allow, t.full_description) do
              test_logger
              expect_disallow_message(second_allow)
            end
          end

          it 'then instance block' do |t|
            patient_jane.allow_phi!(first_allow, t.full_description)
            patient_jane.allow_phi(second_allow, t.full_description) do
              test_logger
              expect_disallow_message(second_allow)
            end
          end

          it 'only one when previously revoked' do |t|
            patient_jane.allow_phi!(first_allow, t.full_description)
            patient_jane.disallow_phi!
            PatientInfo.allow_phi!(second_allow, t.full_description)
            expect(PhiAttrs::Logger.logger).to receive(:info).with(Regexp.new(second_allow))
            patient_jane.first_name
          end
        end
      end

      context 'for disallow_phi!' do
        it 'class' do |t|
          PatientInfo.allow_phi!(first_allow, t.full_description)
          PatientInfo.allow_phi!(second_allow, t.full_description)
          expect(PhiAttrs::Logger.logger).to receive(:info).with(regexp)
          PatientInfo.disallow_phi!
        end

        it 'instance' do |t|
          patient_jane.allow_phi!(first_allow, t.full_description)
          patient_jane.allow_phi!(second_allow, t.full_description)
          expect(PhiAttrs::Logger.logger).to receive(:info).with(regexp)
          patient_jane.disallow_phi!
        end
      end
    end
  end
end
