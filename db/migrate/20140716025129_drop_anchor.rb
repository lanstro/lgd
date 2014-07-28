class DropAnchor < ActiveRecord::Migration
  def change
		drop_table :anchors
  end
end
