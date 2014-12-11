# == Schema Information
#
# Table name: comments
#
#  id             :integer          not null, primary key
#  content        :string(255)
#  user_id        :integer
#  container_id   :integer
#  reputation     :integer
#  created_at     :datetime
#  updated_at     :datetime
#  ancestry       :string(255)
#  ancestry_depth :integer
#  flags_count    :integer
#
# Indexes
#
#  index_comments_on_ancestry      (ancestry)
#  index_comments_on_container_id  (container_id)
#

class Comment < ActiveRecord::Base
	
	validates :user, presence: true
	validates :container, presence: true
	validates :parent, presence: true, :allow_blank => true
	belongs_to :user
	belongs_to :container
	delegate :act, :to => :container, :allow_nil => true
	validates :content, presence: true, length: { maximum: 5000 }
	
	has_many :flags, as: :flaggable, dependent: :destroy
	
	has_ancestry orphan_strategy: :adopt, cache_depth: true
	default_scope -> {order('created_at ASC')} 
	
	# TODO MEDIUM: admin deletion/hiding of comments
	
end
