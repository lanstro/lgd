class AddAncestryToComments < ActiveRecord::Migration
  def change
    add_column :comments, :ancestry, :string
		add_index :comments, :ancestry
		drop_table :comment_hierarchies
  end
end
