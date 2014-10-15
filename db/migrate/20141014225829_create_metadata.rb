class CreateMetadata < ActiveRecord::Migration
  def change
    create_table :metadata do |t|
      t.integer :scope_id
      t.string  :scope_type
      t.integer :content_id
      t.string  :content_type
      t.string  :anchor
      t.string  :type

      t.timestamps
    end
  end
end
