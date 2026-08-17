# frozen_string_literal: true

# Entries default to active because most specs care about what a local node can
# see. Use the :draft trait for the curation side.
FactoryBot.define do
  trait :dictionary_defaults do
    status { DictionaryEntry::ACTIVE }
  end

  trait :draft do
    status { DictionaryEntry::DRAFT }
  end

  trait :retired do
    status { DictionaryEntry::RETIRED }
  end

  factory :department do
    dictionary_defaults
    sequence(:name) { |n| "Secção #{n}" }
  end

  factory :specimen_type do
    dictionary_defaults
    sequence(:name) { |n| "Espécime #{n}" }
  end

  factory :drug do
    dictionary_defaults
    sequence(:name) { |n| "Fármaco #{n}" }
  end

  factory :organism do
    dictionary_defaults
    sequence(:name) { |n| "Organismo #{n}" }
  end

  factory :test_panel do
    dictionary_defaults
    sequence(:name) { |n| "Painel #{n}" }
  end

  factory :rejection_reason do
    dictionary_defaults
    sequence(:name) { |n| "Motivo de rejeição #{n}" }
  end

  factory :indicator do
    dictionary_defaults
    sequence(:name) { |n| "Indicador #{n}" }
    value_type { "Numeric" }
    unit { "g/dL" }
  end

  factory :test_type do
    dictionary_defaults
    sequence(:name) { |n| "Teste #{n}" }
    performed_on_sex { "Both" }
  end

  factory :indicator_range do
    indicator
    sex { "Both" }
    age_min { 0 }
    age_max { 120 }
    range_lower { 12.0 }
    range_upper { 16.0 }
  end

  factory :external_mapping do
    system { "mlab" }
    entity_type { "test_types" }
    entity_uuid { SecureRandom.uuid }
    sequence(:external_code) { |n| "MLAB-#{n}" }
  end
end
