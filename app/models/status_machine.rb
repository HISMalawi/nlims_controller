# frozen_string_literal: true

# Which status may follow which, for one kind of record.
#
# The map is the entire definition: a transition that is not listed does not
# exist, and a status nothing leads out of is terminal. Writing it once, here,
# is what makes "a completed order cannot go back to requested" a property of
# the system rather than a check each endpoint has to remember.
class StatusMachine
  attr_reader :initial, :transitions, :statuses

  def initialize(initial:, transitions:)
    @initial = initial
    @transitions = transitions.transform_values { |targets| targets.dup.freeze }.freeze
    @statuses = ([ initial ] + transitions.keys + transitions.values.flatten).uniq.freeze
    freeze
  end

  def include?(status)
    statuses.include?(status)
  end

  def next_statuses(from)
    transitions.fetch(from, [])
  end

  def allows?(from, to)
    next_statuses(from).include?(to)
  end

  def terminal?(status)
    next_statuses(status).empty?
  end
end
