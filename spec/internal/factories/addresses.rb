# frozen_string_literal: true

FactoryBot.define do
  factory :address do
    address { '123 Little Whinging' }

    trait :all_random do
      address { Faker::Movies::HarryPotter.location }
    end
  end
end
