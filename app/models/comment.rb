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
#
# Indexes
#
#  index_comments_on_ancestry      (ancestry)
#  index_comments_on_container_id  (container_id)
#

class Comment < ActiveRecord::Base
	
	validates :user_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :container_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :parent_id, numericality: {only_integer: true}, :allow_blank => true
	belongs_to :user
	belongs_to :container
	delegate :act, :to => :container, :allow_nil => true
	validates :content, presence: true, length: { maximum: 5000 }
	
	has_ancestry orphan_strategy: :adopt, cache_depth: true
	default_scope -> {order('created_at ASC')} 
end
