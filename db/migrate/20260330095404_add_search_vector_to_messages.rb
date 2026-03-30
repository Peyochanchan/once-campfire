class AddSearchVectorToMessages < ActiveRecord::Migration[8.2]
  def change
    add_column :messages, :searchable, :tsvector
    add_index :messages, :searchable, using: :gin
  end
end
