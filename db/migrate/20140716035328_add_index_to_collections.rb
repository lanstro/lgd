class AddIndexToCollections < ActiveRecord::Migration
  def change
  end
	add_index :collections_containers, [:container_id, :collection_id]
end
