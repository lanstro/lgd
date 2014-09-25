class DropContainerHierarchies < ActiveRecord::Migration
  def change
		drop_table :container_hierarchies
  end
end
