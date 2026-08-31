# frozen_string_literal: true

# A refusal the client can act on, carrying the field it happened in.
#
# A payload from an EMR or a laboratory names fifteen dictionary codes, and
# being told that one of them is wrong without being told which is barely better
# than not being told at all. Every endpoint renders this the same way, so the
# field arrives whether the refusal came from the intake, a lab report or a
# rejection.
class InvalidRequest < StandardError
  attr_reader :field

  def initialize(message, field:)
    super(message)
    @field = field
  end
end
