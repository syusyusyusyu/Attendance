class CreateSsoProvidersAndIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :sso_providers do |t|
      t.string :name, null: false
      t.string :strategy, null: false
      t.string :client_id
      t.string :client_secret
      t.string :authorize_url
      t.string :token_url
      t.string :issuer
      t.boolean :enabled, null: false, default: false
      t.timestamps
    end

    add_index :sso_providers, :name, unique: true

    create_table :sso_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sso_provider, null: false, foreign_key: true
      t.string :uid, null: false
      t.string :email
      t.timestamps
    end

    add_index :sso_identities, [:sso_provider_id, :uid], unique: true
  end
end
