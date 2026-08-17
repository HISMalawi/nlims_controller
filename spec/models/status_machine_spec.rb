# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatusMachine do
  subject(:machine) do
    described_class.new(
      initial: "novo",
      transitions: {
        "novo" => [ "aberto", "anulado" ],
        "aberto" => [ "fechado" ]
      }
    )
  end

  it "knows every status it names, including the ones only reachable as targets" do
    expect(machine.statuses).to contain_exactly("novo", "aberto", "anulado", "fechado")
  end

  it "allows only the transitions it lists" do
    expect(machine.allows?("novo", "aberto")).to be(true)
    expect(machine.allows?("novo", "fechado")).to be(false)
  end

  # A machine that let a status be reached from anywhere would make the map
  # decorative. Backwards is the case that matters: it is what an out-of-order
  # message from a laboratory looks like.
  it "does not run backwards" do
    expect(machine.allows?("fechado", "aberto")).to be(false)
  end

  it "treats a status nothing leads out of as terminal" do
    expect(machine.terminal?("fechado")).to be(true)
    expect(machine.terminal?("anulado")).to be(true)
    expect(machine.terminal?("novo")).to be(false)
  end

  it "reports an unknown status as neither known nor reachable" do
    expect(machine.include?("inventado")).to be(false)
    expect(machine.next_statuses("inventado")).to be_empty
  end
end
