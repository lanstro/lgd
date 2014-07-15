class ChangeNameOfAnchorInAnchors < ActiveRecord::Migration
  def change
		rename_column :anchors, :anchor, :anchor_text
  end
end
