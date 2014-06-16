class AddIndexToActs < ActiveRecord::Migration
  def change
  end
	add_index :acts, [:year, :number]
end
