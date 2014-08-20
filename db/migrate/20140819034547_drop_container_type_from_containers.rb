class DropContainerTypeFromContainers < ActiveRecord::Migration
  def change
		remove_column :containers, :container_type, :string
		add_column :containers, :depth, :integer
  end
end
