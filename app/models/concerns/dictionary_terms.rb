# frozen_string_literal: true

# How a transactional row points at a clinical term.
#
# Every such row used to hold nothing but a foreign key, which meant the row
# could not exist until the dictionary did. Each term declared here keeps three
# columns instead — the key, the name and the code — so a term the dictionary
# already carries is linked, a term it does not is still written down, and the
# two read the same way from the outside.
#
#   dictionary_term :test_type, entity: "test_types", name: :test_name, code: :test_code
#
# gives `test_type_reference` and its setter, `test_type_label` for anything
# that has to render the term, and `test_type_known?` for the reports that count
# how much of the day's work the dictionary can actually account for.
module DictionaryTerms
  extend ActiveSupport::Concern

  class_methods do
    def dictionary_term(association, entity:, name:, code:)
      belongs_to association, optional: true

      define_method(:"#{association}_reference") do
        entry = public_send(association)

        Dictionary::Reference.new(
          entry: entry,
          code: public_send(code).presence || entry&.national_code,
          name: public_send(name).presence || entry&.name
        )
      end

      define_method(:"#{association}_reference=") do |value|
        reference = value.is_a?(Dictionary::Reference) ? value : Dictionary::Reference.resolve(entity, value)

        public_send(:"#{association}=", reference.entry)
        public_send(:"#{code}=", reference.code)
        public_send(:"#{name}=", reference.name)
      end

      define_method(:"#{association}_label") { public_send(:"#{association}_reference").label }
      define_method(:"#{association}_known?") { public_send(association).present? }
    end
  end
end
