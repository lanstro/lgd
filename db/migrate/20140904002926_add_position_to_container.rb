class AddPositionToContainer < ActiveRecord::Migration
  def change
    add_column :containers, :position, :integer
  end
end
