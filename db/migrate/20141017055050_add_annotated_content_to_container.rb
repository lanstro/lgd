class AddAnnotatedContentToContainer < ActiveRecord::Migration
  def change
    add_column :containers, :annotated_content, :string
  end
end
