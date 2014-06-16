class Act < ActiveRecord::Base
	has_many :sections, dependent: :destroy
	validates :title, presence: true
	validates :last_updated, presence: true
	validates :jurisdiction, presence: true, inclusion: { in: ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"] }
	validates :act_type, presence: true, inclusion: { in: %w{Act Regulations} }
	validates :year, presence: true, numericality: {only_integer: true, greater_than: 1900, less_than_or_equal_to: Time.now.year}
	validates :number, presence: true, numericality: {only_integer: true, greater_than: 0}
end
