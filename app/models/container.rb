class Container < ActiveRecord::Base
	belongs_to :act
	belongs_to :parent,   class_name: "Container"
	has_many   :children, class_name: "Container", foreign_key: "parent_id"
	validates_presence_of :act
	validates :act_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :number, presence: true
	validates :container_type, presence: true, inclusion: { in: ["Chapter", "Part", "Division", "Subdivision", "Section", "Subsection", "Regulation", "Schedule", "Note", "Paragraph",]}
	validates :regulations, numericality: {only_integer: true, greater_than: 0}, :allow_blank => true
	default_scope -> {order('number ASC')}
end
