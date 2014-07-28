class Container < ActiveRecord::Base
	belongs_to :act
	belongs_to :parent,   class_name: "Container"
	has_many   :children, class_name: "Container", foreign_key: "parent_id"
	has_and_belongs_to_many :collections
	validates_presence_of :act
	validates :act_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :number, presence: true
	validates :container_type, presence: true, inclusion: { in: ["Chapter", "Part", "Division", "Subdivision", "Section", "Subs_1",  "Subs_2", "Subs_3", "Subs_4","Regulation", "Schedule", "Note", "Paragraph","Title", "Subheading"]}
	validates :regulations, numericality: {only_integer: true, greater_than: 0}, :allow_blank => true
	default_scope -> {order('id ASC')} # need to refine
end
