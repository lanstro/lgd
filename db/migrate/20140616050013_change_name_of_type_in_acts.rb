class ChangeNameOfTypeInActs < ActiveRecord::Migration
  def change
		rename_column :acts, :type, :act_type
  end
end
