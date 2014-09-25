class RenameDepthToLevelOnContainers < ActiveRecord::Migration
  def change
		rename_column :containers, :depth, :level
  end
end
