class Metadata < ActiveRecord::Base
	belongs_to :scope,               class_name: "Collection"
	belongs_to :metadata_content,    class_name: "Collection"
	validates :meta_type, presence: true, inclusion: { in: ["definition", "external_link", "penalty"]}
	validates :external_link, presence: true, unless: lambda { self.meta_type != "external_link" }
	validates :metadata_content, presence: true, unless: lambda { self.meta_type == "external_link" }
	validates :scope, presence: true
end
