class ChangeAnnotatedContentToText < ActiveRecord::Migration
  def change
		change_column :containers, :annotated_content, :text, :limit => nil
  end
end
