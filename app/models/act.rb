class Act < ActiveRecord::Base
	has_many :sections, dependent: :destroy
	validates :title, presence: true
	validates :last_updated, presence: true
	validates :jurisdiction, presence: true, inclusion: { in: ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"] }
	validates :act_type, presence: true, inclusion: { in: %w{Act Regulations} }
	validates :year, presence: true, numericality: {only_integer: true, greater_than: 1900, less_than_or_equal_to: Time.now.year}
	validates :number, presence: true, numericality: {only_integer: true, greater_than: 0}
	
	
	def parsed_content
		result = []
		File.open(Rails.root+"legislation/AIA.txt", "rb").each_line do |line| 
			result.push parse_line(line)
		end
		result.delete_if { |line| line.blank? }
		return result
	end
	
	def parse_line(line)
		line.gsub!("<Act>", "")
		line.gsub!("</Act>", "")
		line.gsub!('<Part>',     					'<div class="Part">')
		line.gsub!('</Part>',    					'</div>')
		line.gsub!('<Section>', 					'<div class="Section">')
		line.gsub!('</Section>', 					'</div>')
		line.gsub!('<Subsection>',  			'<div class="Subsection">')
		line.gsub!('</Subsection>', 			'</div>')
		line.gsub!('<Definition>',  			'<div class="Definition">')
		line.gsub!('</Definition>', 			'</div>')
		line.gsub!('<Paragraph>',  				'<p>')
		line.gsub!('</Paragraph>', 				'</p>')
		line.gsub!('<Explanatory_box>',  	'<div class="Explanatory_box">')
		line.gsub!('</Explanatory_box>', 	'</div>')
		line.gsub!('<List>',  						'<ol>')
		line.gsub!('</List>', 						'</ol>')
		line.gsub!('<List_item>',  				'<li>')
		line.gsub!('</List_item>', 				'</li>')
		line.gsub!('<Note>',  				    '<p class="Note">')
		line.gsub!('</Note>', 						'</p>')
		line.gsub!('<Title>',  				    '<h2>')
		line.gsub!('</Title>', 						'</h2>')
		return line
	end
	
end
