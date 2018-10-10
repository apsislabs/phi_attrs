# frozen_string_literal: true

FactoryBot.define do
  factory :patient_detail do
    detail { 'Generic Spell' }

    trait :all_random do
      detail { Faker::HarryPotter.spell }
    end
  end
end
