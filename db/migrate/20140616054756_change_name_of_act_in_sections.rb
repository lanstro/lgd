class ChangeNameOfActInSections < ActiveRecord::Migration
  def change
		rename_column :sections, :act, :act_id
  end
end
