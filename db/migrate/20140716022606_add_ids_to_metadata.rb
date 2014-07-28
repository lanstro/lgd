class AddIdsToMetadata < ActiveRecord::Migration
  def change
    add_column :metadata, :scope_id, :integer
    add_column :metadata, :metadata_content_id, :integer
  end
end
