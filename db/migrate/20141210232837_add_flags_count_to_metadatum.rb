class AddFlagsCountToMetadatum < ActiveRecord::Migration
  def change
    add_column :metadata, :flags_count, :integer
  end
end
