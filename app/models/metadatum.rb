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

class Metadatum < ActiveRecord::Base
	belongs_to :scope,    polymorphic: true
	belongs_to :content,  polymorphic: true
	
	validates_presence_of :anchor
	validates :type, presence: true, inclusion:    { in: ["Definition", "Internal_reference", "Hyperlinks"] }
	
	scope :definitions,          -> { where(type: 'Definition') } 
	scope :internal_references,  -> { where(type: 'Internal_reference') } 
	scope :hyperlinks,           -> { where(type: 'Hyperlink') }
	
end
