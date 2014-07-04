class RemoveTitleFromContainer < ActiveRecord::Migration
  def change
    remove_column :containers, :title, :string
  end
end
