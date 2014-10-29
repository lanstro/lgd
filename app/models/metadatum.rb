# == Schema Information
#
# Table name: metadata
#
#  id              :integer          not null, primary key
#  scope_id        :integer
#  scope_type      :string(255)
#  content_id      :integer
#  content_type    :string(255)
#  anchor          :text
#  category        :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  universal_scope :boolean
#
# Indexes
#
#  index_metadata_on_content_id_and_content_type  (content_id,content_type)
#  index_metadata_on_scope_id_and_scope_type      (scope_id,scope_type)
#

class Metadatum < ActiveRecord::Base
	belongs_to :scope,    polymorphic: true
	belongs_to :content,  polymorphic: true
	
	has_many :annotations, dependent: :destroy
	
	validates_presence_of :anchor
	validates :category, presence: true, inclusion:    { in: ["Definition", "Internal_reference"] }
	
	validates :scope, presence: { :message => "does not exist." }, unless: :universal_scope?
	validates :scope_type, presence: true, inclusion:    { in: ["Act", "Container"] }, unless: :universal_scope?
		
	validates :content, presence: { :message => "does not exist." }
	validates :content_type, presence: true, inclusion:    { in: ["Act", "Container"] }
		
	before_save :erase_scope_if_universal
	
	scope :definitions,          -> { where(category: 'Definition') } 
	scope :internal_references,  -> { where(category: 'Internal_reference') } 

	serialize :anchor
		
	# TODO MEDIUM: ensure uniqueness of content, scope, anchor
		
	private
		
		def erase_scope_if_universal
			if self.universal_scope?
				self.scope=nil
				self.scope_type=nil
			end
		end
	
end
