class AddAncestryDepthToComments < ActiveRecord::Migration
  def change
    add_column :comments, :ancestry_depth, :integer
  end
end
