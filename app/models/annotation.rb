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
	
	validates :metadatum, presence: true, if: :meta_link?
	validates :container, presence: true
	
	validates :anchor,   presence: true
	validates :position, presence: true, numericality: {only_integer: true, greater_than: -1}
	
	# TODO medium: validate the container itself and see whether the anchor actually exists in that position
	
	validates :category, presence: true, inclusion:    { in: ["Metadatum", "Defined_term", "Hyperlink", "Placeholder"] }
	
	# TODO medium: see which of these should be implemented
	# callback - whenever the anchor changes, test container again
	# callback - whenever container content changes, see if position/anchor still valid.  If not, self-delete and log it
	# callback - whenever metadata anchor changes, test container again
	# callback - when this is destroyed, re-evaluate container
	
	def open_tag
		if self.category=="Defined_term"
			return "<span class='defined_term'>"
		elsif self.category=="Hyperlink"
			return "<a href='"+self.hyperlink+"'"  # Todo medium: finish this off, and consider removing hyperlink class
		elsif self.category=="Placeholder"
			return "<span class='reference'>"
		elsif self.category=="Metadatum"
			data = "data-metadata_link='"+self.metadatum.content.id.to_s+"'"
			case self.metadatum.type
				when "Definition"
					return "<span class='definition_anchor'"+data+">"
				when Internal_reference
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
