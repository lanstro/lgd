class AddComlawIdToActs < ActiveRecord::Migration
  def change
    add_column :acts, :comlawID, :string
  end
end
