class RenameMetadataTypeToCategory < ActiveRecord::Migration
  def change
		rename_column :metadata, :type, :category
  end
end
