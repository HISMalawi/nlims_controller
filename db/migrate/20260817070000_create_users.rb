# frozen_string_literal: true

# People who sign in to the interface. Nothing to do with api_clients: a client
# is a system holding a key, a user is a person holding a password, and the two
# never authenticate the same request.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :uuid, limit: 36, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, limit: 16, null: false, default: "operator"

      # A person who has left keeps their history — their name is on status
      # events and on issued keys — but stops being able to sign in.
      t.boolean :active, null: false, default: true

      # Which facility this person works at, so a node deployed at a hospital
      # can show its own samples first. Blank on the national node.
      t.string :facility_code, limit: 16

      t.datetime :last_signed_in_at

      t.timestamps

      t.index :uuid, unique: true
      t.index :email, unique: true
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true

      # Kept so an operator can see where they are signed in, and so a session
      # opened from a machine that should not have had it can be recognised.
      t.string :ip, limit: 45
      t.string :user_agent

      t.datetime :last_seen_at, null: false

      t.timestamps

      t.index :last_seen_at
    end
  end
end
