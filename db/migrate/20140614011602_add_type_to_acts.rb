class AddTypeToActs < ActiveRecord::Migration
  def change
		add_column :acts, :type, :string
		add_column :acts, :year, :integer
		add_column :acts, :number, :integer
  end
end
