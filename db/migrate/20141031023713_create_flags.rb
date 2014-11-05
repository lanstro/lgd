class CreateFlags < ActiveRecord::Migration
  def change
    create_table :flags do |t|
      t.string  :category
      t.integer :user_id
      t.integer :flaggable_id
      t.string  :flaggable_type
			t.string  :comment
      t.timestamps
    end
  end
end
