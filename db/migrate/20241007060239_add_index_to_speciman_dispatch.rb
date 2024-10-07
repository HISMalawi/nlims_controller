# frozen_string_literal: true

# Add index to specime_dispatch
class AddIndexToSpecimanDispatch < ActiveRecord::Migration[7.1]
  def change
    add_index :specimen_dispatches, %i[tracking_number dispatcher_type_id], name: 'idx_track_num_dispatch_type'
  end
end
