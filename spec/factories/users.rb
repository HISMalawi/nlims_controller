# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Operador #{n}" }
    sequence(:email) { |n| "operador#{n}@hcm.gov.mz" }
    password { "palavra-passe-boa" }
    role { User::OPERATOR }
    active { true }

    trait :admin do
      role { User::ADMIN }
    end

    trait :disabled do
      active { false }
    end
  end

  factory :session do
    user
    ip { "10.0.0.7" }
    user_agent { "Mozilla/5.0" }
    last_seen_at { Time.current }
  end
end
