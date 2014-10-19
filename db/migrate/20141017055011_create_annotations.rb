class CreateAnnotations < ActiveRecord::Migration
  def change
    create_table :annotations do |t|
      t.integer :metadatum_id
      t.integer :container_id
      t.string :anchor
      t.integer :position

      t.timestamps
    end
  end
end
