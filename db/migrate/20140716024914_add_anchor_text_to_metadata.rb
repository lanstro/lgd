class AddAnchorTextToMetadata < ActiveRecord::Migration
  def change
    add_column :metadata, :anchor_text, :string
  end
end
