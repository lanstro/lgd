class AddRecordsToContainers < ActiveRecord::Migration
  def change
    add_column :containers, :definition_parsed, :DateTime
    add_column :containers, :references_parsed, :DateTime
    add_column :containers, :annotation_parsed, :DateTime
  end
end
