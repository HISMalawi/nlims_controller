# frozen_string_literal: true

# Add index to specimen_dispatch
class AddIndexToSpecimanDispatch < ActiveRecord::Migration[7.1]
  def change
    if column_exists?(:specimen_dispatches, :dispatcher_type_id) &&
       !index_exists?(:specimen_dispatches, %i[tracking_number dispatcher_type_id], name: 'idx_track_num_dispatch_type')
      add_index :specimen_dispatches, %i[tracking_number dispatcher_type_id], name: 'idx_track_num_dispatch_type'
    end
  end
end
