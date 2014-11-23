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
#  metadata_uniqueness                            (anchor,scope_id,scope_type,content_id,content_type,universal_scope,category) UNIQUE
#

class Metadatum < ActiveRecord::Base
	belongs_to :scope,    polymorphic: true
	belongs_to :content,  polymorphic: true
	
	serialize :anchor, Array
	
	has_many :annotations, dependent: :destroy
	has_many :flags, as: :flaggable, dependent: :destroy
	
	validates_presence_of :anchor
	validates :category, presence: true, inclusion:    { in: ["Definition", "Internal_reference"] }
	
	validates :scope, presence: { :message => "does not exist." }, unless: :universal_scope?
	validates :scope_type, presence: true, inclusion:    { in: ["Act", "Container"] }, unless: :universal_scope?
		
	validates :content, presence: { :message => "does not exist." }
	validates :content_type, presence: true, inclusion:    { in: ["Act", "Container"] }
		
	before_validation :arrange_anchors_alphabetically
		
	before_save :erase_scope_if_universal
	
	scope :definitions,          -> { where(category: 'Definition') } 
	scope :internal_references,  -> { where(category: 'Internal_reference') } 

	validates :anchor, uniqueness: { scope: [:scope_id, :scope_type, :content_id, :content_type, :universal_scope, :category],
																	 message: "The metadata already exists in the database." }
			
	# TODO MEDIUM: ensure uniqueness of content, scope, anchor
	
	after_destroy :check_content_container
	
	def save_and_check_dependencies(params)
		self.assign_attributes(params)
		changes = self.changes
		if self.save
			if changes[:content_id]
				# check whether old annotations should be deleted
				check_content_container(old = changes[:content_id][0])
				# add italics/bold to the defined term
				# TODO LOW: consider whether more elegant way of doing this
				anchors.each do |anchor|
					position = self.content.content.index(subject_words)
					if position
						self.content.create_annotation(category: "Defined_term", anchor: anchor, position: position)
						break
					end
				end
			end
			if changes [:anchor]
				additions = changes[:anchor][1] - changes[:anchor][0]
				removals  = changes[:anchor][0] - changes[:anchor][1]
				#- if any anchors deleted, find all annotations with anchor == the deleted anchor, delete those
				removals.each do |anchor|
					self.anchors.where(anchor: anchor).each(&:destroy)
				end
				#- if any anchors added, look for it over all the scope
				self.scope.subtree.each do |container|
					container.process_metadata_anchors([self])
				end
			end
			if changes[:scope_id]
				#- treat as if old one deleted
				self.annotations.each(&:destroy)
				#- then new scope added
				self.scope.subtree.each do |container|
					container.process_metadata_anchors([self])
				end
			end
			return true
		else
			return false
		end
	end
	
	def arrange_anchors_alphabetically
		anchor.sort!
	end
	
	def check_content_container(old_id=nil)
		# rerun annotations of the content container (to remove the bold/italics definitions)
		return if self.category != "Definition"
		relevant_annotations = []
		old_id ||= self.content_id
		self.anchor.each do |anchor|
			relevant_annotations += Annotation.where(container_id: old_id, anchor: anchor, category: "Defined_term")
		end
		relevant_annotations.each { |a| a.destroy }
		# no need to force recalculation of annotations ourselves - should be done by the annotation's callback
	end
		
	def within_scope?(container)
		return false if !container
		return true if universal_scope
		return (container==scope or container.ancestors.include?(scope) or container.act == scope)
	end
		
	private
		
		def erase_scope_if_universal
			if self.universal_scope?
				self.scope=nil
				self.scope_type=nil
			end
		end
	
end
