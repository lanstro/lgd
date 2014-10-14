class AddPublishedToAct < ActiveRecord::Migration
  def change
    add_column :acts, :published, :boolean
  end
end
