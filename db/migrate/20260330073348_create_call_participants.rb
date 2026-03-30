class CreateCallParticipants < ActiveRecord::Migration[8.2]
  def change
    create_table :call_participants do |t|
      t.references :room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :joined_at, null: false

      t.timestamps
    end

    add_index :call_participants, [ :room_id, :user_id ], unique: true
  end
end
