class DropApiKeys < ActiveRecord::Migration[8.0]
  def change
    drop_table :api_keys, if_exists: true
  end
end
