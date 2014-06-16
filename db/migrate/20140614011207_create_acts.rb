class CreateActs < ActiveRecord::Migration
  def change
    create_table :acts do |t|
      t.string :title
      t.date :last_updated
      t.string :jurisdiction
      t.text :updating_acts
      t.string :subtitle
      t.string :regulations

      t.timestamps
    end
  end
end
