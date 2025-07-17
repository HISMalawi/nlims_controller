# frozen_string_literal: true

# Add acknowledgements to result ack
class AddacknowlegmentToResultAck < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:results_acknwoledges, :acknowledgment_level)

    add_column :results_acknwoledges, :acknowledgment_level, :int
  end
end
