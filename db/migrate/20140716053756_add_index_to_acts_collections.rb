class AddIndexToActsCollections < ActiveRecord::Migration
  def change
  end
	add_index :acts_collections, [:act_id, :collection_id]
end
