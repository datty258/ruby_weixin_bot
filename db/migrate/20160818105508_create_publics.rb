class CreatePublics < ActiveRecord::Migration
  def change
    create_table :publics do |t|
      t.string :user_name
      t.string :nick_name
      t.string :img_url
      t.integer :sex
      t.integer :member_count
      t.string :alias

      t.timestamps null: false
    end
  end
end
