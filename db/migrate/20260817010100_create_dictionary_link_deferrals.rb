# frozen_string_literal: true

# A link whose target has not arrived yet.
#
# The feed is ordered by revision, which is not the order things were created.
# A test type last touched at revision 100 arrives before an indicator renamed
# at revision 500, even though the indicator is older — so on a first sync a
# link routinely arrives before the entry it points at. Dropping it would leave
# the link missing for good, because the owner is not re-sent once its revision
# has been delivered.
class CreateDictionaryLinkDeferrals < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionary_link_deferrals do |t|
      t.string :owner_entity_type, null: false, limit: 32
      t.string :owner_uuid, null: false, limit: 36
      t.string :link_name, null: false, limit: 32
      t.string :target_code, null: false, limit: 32

      t.datetime :created_at, null: false
    end

    add_index :dictionary_link_deferrals, %i[owner_uuid link_name target_code],
              unique: true, name: "idx_link_deferrals_unique"
    add_index :dictionary_link_deferrals, :target_code
  end
end
