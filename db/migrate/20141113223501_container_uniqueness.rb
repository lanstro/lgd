class ContainerUniqueness < ActiveRecord::Migration
  def change
		add_index :containers, [:content, :act_id, :ancestry, :number, :position], :unique => true, :name => 'container_uniqueness'
  end
end
