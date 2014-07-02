class ChangeNameOfTypeInContainers < ActiveRecord::Migration
  def change
		rename_column :containers, :section_type, :container_type
  end
end
