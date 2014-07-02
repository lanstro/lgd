class ChangeSectionsToContainers < ActiveRecord::Migration
  def change
		rename_table :sections, :containers
  end
end
