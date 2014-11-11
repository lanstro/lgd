# == Schema Information
#
# Table name: flags
#
#  id             :integer          not null, primary key
#  category       :string(255)
#  user_id        :integer
#  flaggable_id   :integer
#  flaggable_type :string(255)
#  comment        :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#

# things that can be flagged - containers, annotations, metadata and comments

class Flag < ActiveRecord::Base
	
	belongs_to :flaggable, polymorphic: true
	delegate :act, :to => :flaggable, :allow_nil => true
	
	validates :flaggable, presence: true
	validates :user_id, numericality: {only_integer: true, greater_than: 0}, allow_blank: true
	validates :category, presence: true, inclusion:    { in: ["Delete", "Review", "User"] }
	
	#			- deletion of a container involves:
	#			- removal from ancestry/positioning
	#     - check whether its children are also flagged for deletion - if so, fine, if not, log/error out
	#			- removal of all its annotations
	#			- if any metadata point at it, removal of all the metadata
	#				- removal of any annotations pointing at that metadata
	#				- recalculating annotated text for any annotations that are removed
	
end
