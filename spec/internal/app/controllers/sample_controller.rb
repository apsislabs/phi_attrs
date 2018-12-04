# frozen_string_literal: true

class SampleController < ActionController::Base
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
