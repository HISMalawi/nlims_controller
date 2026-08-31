# frozen_string_literal: true

module Dictionary
  # A clinical term as a request named it, and the dictionary entry it turned
  # out to be — if it turned out to be one.
  #
  # This is what replaced `Dictionary.entry!`. That method refused any term the
  # dictionary did not already carry as an active entry, which is the right rule
  # for a consolidated catalogue and the wrong one for this one: the national
  # dictionary is still being assembled, and refusing a laboratory's everyday
  # exam because the catalogue has not reached it yet stops the work rather than
  # protecting it.
  #
  # So a term is looked up and, when it is not found, kept as it was written.
  # The name and code are stored on the row next to the foreign key, so an entry
  # that appears in the dictionary later can be linked to readings already
  # taken, and nothing has to be entered a second time.
  class Reference
    # The payload keys that carry a term. Anything under one of these names is
    # allowed to arrive as a bare string as well as an object — see `expand`.
    # `reason` as well as `rejection_reason`: a rejection sends the reason under
    # the shorter name, at the top level of the body.
    PAYLOAD_KEYS = %w[test_type test_panel specimen_type indicator rejection_reason reason].freeze

    ATTRIBUTES = %i[national_code uuid name].freeze

    attr_reader :entry, :code, :name

    class << self
      # The term a client named. `value` is a string, a hash, an
      # ActionController::Parameters, a dictionary entry, or nothing.
      def resolve(entity_type, value, field: nil)
        return value if value.is_a?(Reference)

        # An entry handed straight in — from a fixture, a seed, or code that had
        # already looked it up. There is nothing to resolve.
        if value.is_a?(ApplicationRecord)
          return new(entry: value, code: value.national_code, name: value.name, field: field)
        end

        given = coerce(value)
        entry = lookup(entity_type, given)

        new(entry: entry,
            code: entry&.national_code || given[:national_code],
            name: entry&.name || given[:name],
            field: field)
      end

      # The same, but a term is required. The only refusal left: a request that
      # names nothing at all cannot be guessed at.
      def resolve!(entity_type, value, field:, message: "é preciso indicar o termo")
        reference = resolve(entity_type, value, field: field)
        raise InvalidRequest.new(message, field: field) if reference.blank?

        reference
      end

      # Turns every bare string sitting under a term key into `{ name: ... }`,
      # anywhere in the payload.
      #
      # Strong parameters drop a key whose declared shape is a hash when a
      # string arrives instead — silently, so an order sent with
      # `"specimen_type": "Sangue total"` would be created with no specimen type
      # and nothing would say so. A name on its own is a legitimate way to name
      # a term, so the string has to survive as far as the permit list.
      def expand(params)
        case params
        when ActionController::Parameters
          expanded = params.to_unsafe_h
          ActionController::Parameters.new(expand(expanded))
        when Hash
          # Built by hand rather than with `to_h { }`: a HashWithIndifferentAccess
          # overrides `to_h` and drops the block, which turned this into a
          # copy that expanded nothing.
          params.each_with_object({}) do |(key, value), expanded|
            expanded[key] =
              if PAYLOAD_KEYS.include?(key.to_s) && value.is_a?(String)
                { "name" => value }
              else
                expand(value)
              end
          end
        when Array
          params.map { |item| expand(item) }
        else
          params
        end
      end

      private

      def coerce(value)
        given =
          case value
          when nil then {}
          when String then { name: value }
          else
            value = value.permit(*ATTRIBUTES) if value.respond_to?(:permit)
            value.to_h.symbolize_keys.slice(*ATTRIBUTES)
          end

        given.transform_values { |item| item.is_a?(String) ? item.strip.presence : item }
      end

      # By uuid, then by national code, then by name.
      #
      # A term given as a bare word is tried as a code as well, because a client
      # sending `"HEM001"` and a client sending `"Hemograma"` both mean "this
      # is what I call the exam" and neither should have to know which of the
      # two this node happens to store it under.
      #
      # Matching by name is the least certain step, so it only matches an active
      # entry and only when exactly one answers to the name — a name two entries
      # share tells us nothing about which was meant.
      def lookup(entity_type, given)
        model = Dictionary.model_for!(entity_type)

        by_uuid(model, given[:uuid]) ||
          by_code(model, given[:national_code]) ||
          by_code(model, given[:name]) ||
          by_name(model, given[:name])
      end

      def by_uuid(model, uuid)
        uuid.present? ? model.find_by(uuid: uuid) : nil
      end

      def by_code(model, code)
        code.present? ? model.find_by(national_code: code) : nil
      end

      def by_name(model, name)
        return nil if name.blank?

        matches = model.active.where(name: name).limit(2).to_a
        matches = model.active.where(short_name: name).limit(2).to_a if matches.empty?
        matches.length == 1 ? matches.first : nil
      end
    end

    def initialize(entry:, code: nil, name: nil, field: nil)
      @entry = entry
      @code = code.presence
      @name = name.presence
      @field = field
    end

    # Whether the term reached an entry in this node's dictionary. A term that
    # did not is not an error — it is a term this node has not been taught yet.
    def known?
      entry.present?
    end

    def blank?
      entry.nil? && code.blank? && name.blank?
    end

    def present?
      !blank?
    end

    # What a person should see. The dictionary's own wording wins when there is
    # one, so an entry renamed nationally reads by its new name everywhere.
    def label
      entry&.name.presence || name.presence || code
    end

    # The term as a refusal should name it: the code when there is one, so the
    # integrator can search for it, and always the name, so a person can read it.
    def description
      return label if code.blank?

      "#{code} (#{label})"
    end

    def as_json(*)
      return nil if blank?

      { uuid: entry&.uuid, national_code: code, name: label }
    end
  end
end
