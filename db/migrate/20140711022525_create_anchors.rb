class CreateAnchors < ActiveRecord::Migration
  def change
    create_table :anchors do |t|
      t.string :anchor

      t.timestamps
    end
  end
end
