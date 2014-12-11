class AddFlagsCountToComments < ActiveRecord::Migration
  def change
    add_column :comments, :flags_count, :integer
  end
end
