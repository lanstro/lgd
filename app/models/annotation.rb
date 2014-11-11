# == Schema Information
#
# Table name: annotations
#
#  id           :integer          not null, primary key
#  metadatum_id :integer
#  container_id :integer
#  anchor       :string(255)
#  position     :integer
#  created_at   :datetime
#  updated_at   :datetime
#  category     :string(255)
#

class Annotation < ActiveRecord::Base
	
	belongs_to :metadatum
	belongs_to :container
	
	has_many :flags, as: :flaggable, dependent: :destroy
	
	validates :metadatum, presence: true, if: :meta_link?
	validates :container, presence: true
	
	validates :anchor,   presence: true
	validates :position, presence: true, numericality: {only_integer: true, greater_than: -1}
	
	validates :category, presence: true, inclusion:    { in: ["Metadatum", "Defined_term", "Hyperlink", "Placeholder"] }
	
	validate :anchor_exists_at_position
	
	after_destroy :rerun_annotated_content
	
	def rerun_annotated_content
		# when this is destroyed, re-evaluate container's annotated_content
		self.container.recalculate_annotations if self.container
	end
	
	
	def anchor_exists_at_position
		if meta_link?
			puts "validating annotation: checking whether the anchor "+anchor+" exists in metadatum "+metadatum.inspect
			if !metadatum or !metadatum.anchor.include?(anchor)
				errors.add(:anchor, "The anchor does not match up with the metadatum object's anchors")
			end
			if !metadatum.within_scope?(container)
				errors.add(:metadatum, "The metadatum's scope does not extend to the container.")
			end
		end
		if !container or !position or !anchor or container.content[(position)..(position+anchor.length-1)] != anchor
			errors.add(:position, "The anchor does not exist at that position in the container.")
		end
	end
	
	def open_tag
		if self.category=="Defined_term"
			return "<span class='defined_term'>"
		elsif self.category=="Hyperlink"
			return "<a href='"+self.hyperlink+"'"  # Todo medium: finish this off, and consider removing hyperlink class
		elsif self.category=="Placeholder"
			return "<span class='reference'>"
		elsif self.category=="Metadatum"
			data = "data-metadata_link='"+self.metadatum.content.id.to_s+"'"
			case self.metadatum.category
				when "Definition"
					return "<span class='definition_anchor'"+data+">"
				when "Internal_reference"
					return "<span class='reference'"+data+">"
			end
		end
	end
	
	def close_tag
		if self.category=="Hyperlink" 
			return "</a>"
		else
			return "</span>"
		end
	end
	
	private
		def meta_link?
			self.category=="Metadatum"
		end
	
end
