class AddIndexToSections < ActiveRecord::Migration
  def change
  end
	add_index :sections, [:act, :number]
end
