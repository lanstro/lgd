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
