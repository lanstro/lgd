class MetadatumUniqueness < ActiveRecord::Migration
  def change
		add_index :metadata, [:anchor, :scope_id, :scope_type, :content_id, :content_type, :universal_scope, :category], 
			:unique => true, :name => 'metadata_uniqueness'
  end
end
