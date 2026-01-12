class DropSsoProvidersAndIdentities < ActiveRecord::Migration[8.0]
  def change
    drop_table :sso_identities, if_exists: true
    drop_table :sso_providers, if_exists: true
  end
end
