class AddContainerIdToAnchor < ActiveRecord::Migration
  def change
    add_column :anchors, :container_id, :integer
  end
end
