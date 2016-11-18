class CreateBots < ActiveRecord::Migration
  def change
    create_table :bots do |t|
      t.string :uin
      t.string :name
      t.string :bash_url
      t.text :cookies
      t.string :synckey_text
      t.string :base_request
      t.text :synckey
      t.string :ticket
      t.integer :is_logout
      t.integer :is_check
      t.text :user_information
      t.string :sync_host

      t.timestamps null: false
    end
  end
end
