class RemoveTagFromContainer < ActiveRecord::Migration
  def change
    remove_column :containers, :tag, :string
  end
end
