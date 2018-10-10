# frozen_string_literal: true

FactoryBot.define do
  factory :health_record do
    data { "I'm sure this is a quote" }

    trait :all_random do
      data { Faker::HarryPotter.quote }
    end
  end
end
