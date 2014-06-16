class CreateSections < ActiveRecord::Migration
  def change
    create_table :sections do |t|
      t.text :number
      t.string :title
      t.date :last_updated
      t.text :updating_acts
      t.string :subtitle
      t.integer :regulations
      t.string :type

      t.timestamps
    end
  end
end
