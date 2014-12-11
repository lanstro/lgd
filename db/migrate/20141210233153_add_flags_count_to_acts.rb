class AddFlagsCountToActs < ActiveRecord::Migration
  def change
    add_column :acts, :flags_count, :integer
  end
end
