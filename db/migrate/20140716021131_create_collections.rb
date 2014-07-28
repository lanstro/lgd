class CreateCollections < ActiveRecord::Migration
  def change
    create_table :collections do |t|

      t.timestamps
    end
		
		create_table :collections_containers, id: false do |t|
			t.integer :collection_id
			t.integer :container_id
		end
		
  end
end
