class AddActsCollectionsTable < ActiveRecord::Migration
  def change
		create_table :acts_collections, id: false do |t|
			t.integer :collection_id
			t.integer :act_id
		end
  end

end
