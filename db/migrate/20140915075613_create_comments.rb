class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.string :content
      t.integer :user_id
      t.integer :container_id
      t.integer :parent_id
      t.integer :reputation

      t.timestamps
    end
		add_index :comments, :container_id
  end
end
