class RemoveParentIdFromComments < ActiveRecord::Migration
  def change
		remove_column :comments, :parent_id
  end
end
