CONTAINER_LEVELS = [nil, "Chapter", "Part", "Division", "Subdivision", "Section", "Subsection", "Paragraph",
											"Subparagraph", "Sub-subparagraph", "Text", "Text"]

class Container < ActiveRecord::Base
	
	belongs_to :act
	belongs_to :parent,   class_name: "Container"
	has_many   :children, class_name: "Container", foreign_key: "parent_id"
	has_and_belongs_to_many :collections
	validates_presence_of :act
	validates :act_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :number, presence: true, unless: lambda { self.depth == TEXT or self.depth == PARA_LIST_HEAD}
	validates :depth, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :regulations, numericality: {only_integer: true, greater_than: 0}, :allow_blank => true
	default_scope -> {order('id ASC')} # need to refine
	
	def container_type
		return CONTAINER_LEVELS[self.depth]
	end
	
	def strip_number
		if self.depth >= SUBSECTION and self.depth <= SUBSUBPARAGRAPH
			close_brace_index = self.content.index(')')
			return self.content[close_brace_index+1..-1].strip
		else
			return self.content
		end
	end
	
end
