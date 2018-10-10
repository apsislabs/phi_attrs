# frozen_string_literal: true

FactoryBot.define do
  factory :patient_info do
    first_name { 'Ronald' }
    last_name { 'Weasley' }

    trait :all_random do
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
    end

    trait :john do
      first_name { 'John' }
      last_name { 'Doe' }
    end

    trait :jane do
      first_name { 'Jane' }
      last_name { 'Doe' }
    end

    trait :jack do
      first_name { 'Jane' }
      last_name { 'Doe' }
    end

  end
end
