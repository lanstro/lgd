class ChangeMetadatumAnchorFromStringToText < ActiveRecord::Migration
  def change
		change_column :metadata, :anchor, :text, :limit => nil
  end
end
