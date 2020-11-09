# frozen_string_literal: true

FactoryBot.define do
  factory :patient_info do
    first_name { 'Joe Johnson' }
    last_name { 'All Houses' }
    association :address, factory: :address, strategy: :build
    association :patient_detail, factory: :patient_detail, strategy: :build

    trait :all_random do
      first_name { Faker::Movies::HarryPotter.character }
      last_name { Faker::Movies::HarryPotter.house }

      association :address, :all_random, factory: :address, strategy: :build
      association :patient_detail, :all_random, factory: :patient_detail, strategy: :build
    end

    trait :with_health_record do
      health_records { build_list(:health_record, 1, :all_random) }
    end

    trait :with_multiple_health_records do
      health_records { build_list(:health_record, 3, :all_random) }
    end
  end
end
