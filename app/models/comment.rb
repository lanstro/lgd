class Comment < ActiveRecord::Base
	
	validates :user_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :container_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :parent_id, numericality: {only_integer: true}, :allow_blank => true
	belongs_to :user
	belongs_to :container
	delegate :act, :to => :container, :allow_nil => true
	validates :content, presence: true, length: { maximum: 5000 }
	
	acts_as_tree :order => 'created_at ASC', :name_column => :id
end
