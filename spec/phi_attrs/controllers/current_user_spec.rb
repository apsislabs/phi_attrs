# frozen_string_literal: true

class SampleController < ApplicationController; end

RSpec.describe 'default user', type: :controller do
  controller SampleController do
    def index
      PatientInfo.allow_phi do
        render json: PatientInfo.all.map(&:summary_json)
      end
    end

    private

    def phi_user
      params[:phi_user]
    end
  end

  before :context do
    PhiAttrs.configure { |c| c.current_user_method = :phi_user }
  end

  after :context do
    PhiAttrs.configure { |c| c.current_user_method = nil }
  end

  before :each do
    create(:patient_info, :all_random, :with_multiple_health_records)
  end

  context 'with translation' do
    it 'uses the translation file for a null reason' do
      message = I18n.t('phi.sample.index.patient_info')
      allow(PhiAttrs::Logger.logger).to receive(:info)

      get :index, params: { phi_user: 'Madame Pomfrey' }

      expect(PhiAttrs::Logger.logger).to have_received(:info).with(include('Madame Pomfrey')).at_least(:once)
      expect(PhiAttrs::Logger.logger).to have_received(:info).with(end_with message).at_least(:once)
    end
  end
end
