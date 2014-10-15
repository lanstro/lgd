class AddIndexToMetadata < ActiveRecord::Migration
  def change
		add_index :metadata, [:scope_id,   :scope_type]
		add_index :metadata, [:content_id, :content_type]
  end
end
