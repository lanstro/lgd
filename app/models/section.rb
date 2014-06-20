class Section < ActiveRecord::Base
	belongs_to :act
	validates_presence_of :act
	validates :act_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :number, presence: true
	validates :section_type, presence: true, inclusion: { in: ["Section", "Regulation", "Schedule", "Part", "Division", "Subdivision", "Chapter", "Definition", "Note", "Title", "Paragraph", "List_item", "List", "Explanatory_box", "Subsection", "Subtitle"], message: "phwar" }
	validates :regulations, numericality: {only_integer: true, greater_than: 0}, :allow_blank => true
	default_scope -> {order('number ASC')}
end
