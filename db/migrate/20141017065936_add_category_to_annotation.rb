class AddCategoryToAnnotation < ActiveRecord::Migration
  def change
    add_column :annotations, :category, :string
  end
end
