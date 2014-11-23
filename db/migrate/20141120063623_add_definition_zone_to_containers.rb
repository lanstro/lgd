class AddDefinitionZoneToContainers < ActiveRecord::Migration
  def change
    add_column :containers, :definition_zone, :boolean
  end
end
