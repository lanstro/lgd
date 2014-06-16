class DeleteSubtitleFromSections < ActiveRecord::Migration
  def change
		remove_column :sections, :subtitle
  end
end
