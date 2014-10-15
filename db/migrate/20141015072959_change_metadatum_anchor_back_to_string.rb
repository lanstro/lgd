class ChangeMetadatumAnchorBackToString < ActiveRecord::Migration
  def change
		change_column :metadata, :anchor, :string
  end
end
