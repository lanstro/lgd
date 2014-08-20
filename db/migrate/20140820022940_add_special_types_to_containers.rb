class AddSpecialTypesToContainers < ActiveRecord::Migration
  def change
    add_column :containers, :special_paragraph, :string
  end
end
