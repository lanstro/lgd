class AddAncestryToContainers < ActiveRecord::Migration
  def change
    add_column :containers, :ancestry, :string
		add_index :containers, :ancestry
		remove_column :containers, :parent_id
  end
	
end
