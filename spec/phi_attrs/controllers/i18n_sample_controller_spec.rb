# frozen_string_literal: true

class SampleController < ApplicationController; end

RSpec.describe 'i18n in controller', type: :controller do
  controller SampleController do
    def index
      PatientInfo.allow_phi('public_user') do
        render json: PatientInfo.all.map(&:summary_json)
      end
    end

    def show
      pi = PatientInfo.find(params[:id])
      pi.allow_phi('public_user') do
        render json: pi.detail_json
      end
    end
  end

  before :each do
    create(:patient_info, :all_random, :with_multiple_health_records)
  end

  context 'with translation' do
    it 'uses the translation file for a null reason' do
      message = I18n.t('phi.sample.index.patient_info')
      allow(PhiAttrs::Logger.logger).to receive(:info)

      get :index
      expect(PhiAttrs::Logger.logger).to have_received(:info).with(end_with message).at_least(:once)
    end
  end

  context 'without translation' do
    it 'warns the user when a translation file was not found' do
      message = 'No en PHI Reason found for phi.sample.show.patient_info'
      allow(PhiAttrs::Logger.logger).to receive(:warn)

      expect do
        get :show, params: { id: PatientInfo.first.id }
      end.to raise_error(ArgumentError)
      expect(PhiAttrs::Logger.logger).to have_received(:warn).with(message)
    end
  end
end
