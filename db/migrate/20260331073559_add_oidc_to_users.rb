class AddOidcToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :oidc_sub, :string
    add_column :users, :oidc_provider, :string
    add_index :users, [ :oidc_sub, :oidc_provider ], unique: true, where: "oidc_sub IS NOT NULL"
  end
end
