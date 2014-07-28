class Collection < ActiveRecord::Base
  has_and_belongs_to_many :containers
	has_and_belongs_to_many :acts
	has_many :metadata_anchors, class_name: "Metadata", foreign_key: "metadata_content_id"
	has_many :scope_anchors,    class_name: "Metadata", foreign_key: "scope_id"
	
	def all
		return self.acts + self.containers
	end
end
