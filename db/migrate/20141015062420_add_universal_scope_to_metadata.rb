class AddUniversalScopeToMetadata < ActiveRecord::Migration
  def change
    add_column :metadata, :universal_scope, :boolean
  end
end
