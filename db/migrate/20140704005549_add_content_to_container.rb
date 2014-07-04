class AddContentToContainer < ActiveRecord::Migration
  def change
    add_column :containers, :content, :text
  end
end
