class CreateMetadata < ActiveRecord::Migration
  def change
    create_table :metadata do |t|
      t.string :meta_type
      t.string :external_link

      t.timestamps
    end
  end
end
