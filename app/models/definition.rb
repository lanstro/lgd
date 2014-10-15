# == Schema Information
#
# Table name: metadata
#
#  id           :integer          not null, primary key
#  scope_id     :integer
#  scope_type   :string(255)
#  content_id   :integer
#  content_type :string(255)
#  anchor       :string(255)
#  type         :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#
# Indexes
#
#  index_metadata_on_content_id_and_content_type  (content_id,content_type)
#  index_metadata_on_scope_id_and_scope_type      (scope_id,scope_type)
#

class Definition < Metadatum
	validates :scope, presence: { :message => "does not exist." }
	validates :scope_type, presence: true, inclusion:    { in: ["Act", "Container"] }
	
	validates :content, presence: { :message => "does not exist." }
	validates :content_type, presence: true, inclusion:    { in: ["Act", "Container"] }
	
	
	
end
