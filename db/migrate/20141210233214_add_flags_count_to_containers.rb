class AddFlagsCountToContainers < ActiveRecord::Migration
  def change
    add_column :containers, :flags_count, :integer
  end
end
