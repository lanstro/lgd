class AddRelationshipsToContainers < ActiveRecord::Migration
  def change
		add_reference :containers, :parent, index: true
  end
end
