# frozen_string_literal: true

# The transactional core. Orders are built at the status they are born in; walk
# them with `transition_to!` rather than setting a later status here, because
# the walk is what produces the history the specs are usually about.
FactoryBot.define do
  factory :patient do
    sequence(:name) { |n| "Doente #{n}" }
    sex { "F" }
    birthdate { Date.new(1991, 4, 12) }

    trait :identified do
      sequence(:national_id) { |n| format("1101002%06dA", n) }
    end
  end

  factory :order do
    patient
    specimen_type
    sending_facility_code { "HCM" }
    receiving_facility_code { "HCM" }
    receiving_lab_code { "HCM-LAB" }
    lab_code { "HCM-LAB-BIOQ" }
    priority { "routine" }
    requested_by { "Dr. J. Sitoe" }
    collected_at { Time.current }
    source_system { "emr" }

    trait :urgent do
      priority { "urgent" }
    end
  end

  factory :order_test do
    order
    test_type
  end

  factory :test_result do
    order_test
    indicator
    value { "12.4" }
    unit { "g/dL" }
    recorded_at { Time.current }
    recorded_by { "tec.mabjaia" }
  end
end
