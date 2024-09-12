# frozen_string_literal: true

# Speciman model
class Speciman < ApplicationRecord
  after_commit :push_order_to_master, on: :create

  private

  def push_order_to_master; end
end
