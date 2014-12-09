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
	
	# TODO HIGH - if a flag is destroyed, whatever it was flagging should be re-run
	# 
	# so definitions should go through its scope again and insert themselves
	# nothing for comments
	# containers should rerun its definitions, anchors and also recalculate annotations
	# nothing for acts

end
