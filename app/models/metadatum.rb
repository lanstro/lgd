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
	has_many :flags, as: :flaggable, dependent: :destroy
	
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
	
	after_destroy :check_content_container
	
	def save_and_check_dependencies(params)
		self.assign_attributes(params)
		changes = self.changes
		if self.save
			if changes[:scope_id]
				#- treat as if old one deleted
				#- then new scope added
			end
			if changes[:content_id]
				# check whether old annotations should be deleted
				# check new content_id for anchors and redo annotations
			end
			if changes [:anchor]
				#- if any anchors deleted, find all annotations with anchor == the deleted anchor, delete those
				#- if any anchors added, look for it over all the scope
				#- if any anchors amended, treat as deletion of old anchor and addition of new anchor
			end
			return true
		else
			return false
		end
	end
	
	def check_content_container
		# rerun annotations of the content container (to remove the bold/italics definitions)
		return if self.category != "Definition"
		relevant_annotations = []
		self.anchors.each do |anchor|
			relevant_annotations += Annotation.where(container_id: self.content_id, anchor: anchor, category: "Defined_term")
		end
		relevant_annotations(&:destroy) 
		# no need to force recalculation of annotations ourselves - should be done by the annotation's callback
	end
		
	def within_scope?(container)
		return false if !container
		return true if universal_scope
		return (container==scope or container.ancestors.include?(scope))
	end
		
	private
		
		def erase_scope_if_universal
			if self.universal_scope?
				self.scope=nil
				self.scope_type=nil
			end
		end
	
end
