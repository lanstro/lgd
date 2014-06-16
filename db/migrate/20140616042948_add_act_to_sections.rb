class AddActToSections < ActiveRecord::Migration
  def change
		add_column :sections, :act, :integer
  end
end
