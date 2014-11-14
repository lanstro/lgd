class AnnotationUniqueness < ActiveRecord::Migration
  def change
		add_index :annotations, [:anchor, :container_id, :metadatum_id, :position], :unique => true, :name => 'annotation_uniqueness'
  end
end
