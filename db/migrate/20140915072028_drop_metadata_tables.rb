class DropMetadataTables < ActiveRecord::Migration
  def change
		drop_table :metadata
		drop_table :collections
		drop_table :collections_containers
		drop_table :acts_collections
  end
end
