# frozen_string_literal: true

FactoryBot.define do
  factory :api_client do
    sequence(:name) { |n| "Cliente #{n}" }
    kind { "emr" }
    facility_code { "HCM" }
    active { true }

    trait :sislab do
      kind { "sislab" }
      lab_code { "HCM-LAB-BIOQ" }
    end

    trait :node do
      kind { "node" }
      facility_code { nil }
      lab_code { nil }
    end

    trait :disabled do
      active { false }
    end
  end
end
