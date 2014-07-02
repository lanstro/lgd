# encoding: UTF-8

# TODO
# define order of [num, lower alpha, roman, capital alpha?]
# consider whether notes should be a structural element type?
# more sophisticated working out whether (i) is an alphabetical element or a roman numeral

####################################################################
#   STRUCTURAL REGEXES                                             #
####################################################################

# structural line types
CHAPTER          = 1
PART             = 2
DIVISION         = 3
SUBDIVISION      = 4
SECTION          = 5
SUBSECTION       = 6
PARAGRAPH        = 7
SUBPARAGRAPH     = 8
UPPER_ALPHA      = 9
LIST             = "List"
DEFINITIONS_LIST = "Definitions_List"

START_INDENTING  = PART

# structural REGEX explanations
# Chapter titles: in a string like 'Chapter xxx-yyyy' or 'Chapter xxx - yyy', extracts the xxx into variable 1 and yyyy into 2,
# Part titles: in a string like 'Part xxx-yyyy' or 'Part xxx - yyy', extracts the xxx into variable 1 and yyyy into 2,
# Section titles: in a string like 'ddww yyyyy', extracts ddww into variable 1 and yyyyy into variable 2
# Subsection titles: in a string like (xx) yyyy', extracts (xx) into variable 1 and yyyy into variable 2
# Notes and examples: matches whole line if the string starts with 'Note: ' or 'Example: '

STRUCTURAL_REGEXES = { 
	SECTION     => [ /\A(\d+\w*)\s+(.+)\Z/,                       "Section",      "Title" ],
	SUBDIVISION => [ /(?<=\ASubdivision\s)\s*(\w*)[-—](.+)\Z/,    "Subdivision",  "Title" ],
	DIVISION    => [ /(?<=\ADivision\s)\s*(\w*)[-—](.+)\Z/,       "Division",     "Title" ],
	PART        => [ /(?<=\APart\s)\s*(\w*)[-—](.+)\Z/ ,          "Part",         "Title" ],
	CHAPTER     => [ /(?<=\AChapter\s)\s*(\w*)[-—](.+)\Z/,        "Chapter",      "Title" ],
}

# indices for STRUCTURAL_REGEXES
REGEX        = 0
OUTER_TAG    = 1
INNER_TAG    = 2

# indices for strings matched by the structural regexes
FULL_STRING  = 0
CONTAINER_NO = 1
HEADING      = 2

####################################################################
#   SUBSECTION REGEX                                               #
####################################################################

SUBSECTION_REGEX = /\A\t*\((\w*)\)\s+(.+)\Z/
SUBSECTION_TAG   = "Subs_"

####################################################################
#   SINGLE LINE REGEXES                                            #
####################################################################

# single line types
NOTES        = "Note"
NORMAL       = "p"
SUBHEADING   = "Subheading"
LIST_INTRO   = "List_intro"

SINGLE_LINE_REGEXES = {
	SUBHEADING => /(?<![\.:;,]|and|or)\s*\Z/ ,
	NOTES      => /\A\s*(Note|Example)\s*:\s+(.*)\Z/
}

# Subheading regex looks for any lines that don't end in a full stop, semicolon, colon or comma.  Must be 
# run after the subsection_regex, because a lot of subsections end in 'and', 'or' etc
# captures the subheading in item 1
# Notes regex looks for lines starting with 'Note:' or 'Example:' - captures that word in item 1 and the
# text in item 2
# list_intro is just the first line of all lists - doesn't need its own regex
# paragraph is the 'catch all'

####################################################################
#   LIST REGEX                                                     #
####################################################################

LIST_REGEX             = /:\s*\z/
DEFINITIONS_LIST_REGEX = /In (this (?:Act|Chapter|Part|Division|[sS]ubdivision|[sS]ection|Schedule)|any Act|[sS]ubsection .+):\s*\Z/

# definitions list regex captures context in item 1
# might need to add 'For the purposes of this act/chapter/etc:'

####################################################################
#   INLINE REGEXES                                                 #
####################################################################

# find 'xxxx Act 19xx'
# 
# tags
DEFINED_TERM = "Defined_term"
REFERENCE    = "Reference"

INLINE_REGEXES = {
	REFERENCE    => /[tT]he ((?:[A-Z]\w+\s)(?:\w+\s)*Act(?:\s\d{4})?)/,
	DEFINED_TERM => /\(the (.+)\)/
}

DEFINITIONS_REGEXES = [
	{ regex: /In (this (?:Act|Chapter|Part|Division|[sS]ubdivision|[sS]ection|Schedule)|any Act|[sS]ubsection .+), (.+) means (.+)\Z/ , context: 1, defined_term: 2 },               # in this xxxx, yyy means zzzz  # captures the context in item 1 and defined term in item 2
	{ regex: /(.+\w),? in relation to (.+),? means(?: .+|:)/,  defined_term: 1, context: 2},    # xxxx, in relation to yyyy(,)? means zzzz # captures defined term in item 1 and context in item 2
	{ regex: /(.+) means(?: .+|:)/,                            defined_term: 1},    # xxx means yyy - captures defined term in item 1
	{ regex: /(.+) has the same meaning as(?: .+|:)/,          defined_term: 1},    # xxx has the same meaning as yyyyy  # captures defined term in item 1
	{ regex: /(.+) includes(?: .+|:)/,                         defined_term: 1},    # xxx includes yyyy # captures defined term in item 1
	{ regex: /(.+): see(?: .+|:)/,                             defined_term: 1},    # xxx: see yyyy #captures defined term in item 1
	{ regex: /(.+) has the meaning given by( .+|:)/,           defined_term: 1}     # xxx has the meaning given by yyyy # captures defined term in item 1 and reference in item 2
]

####################################################################
#   MODEL                                                          #
####################################################################

class Act < ActiveRecord::Base
	has_many :containers, dependent: :destroy
	validates :title, presence: true
	validates :last_updated, presence: true
	validates :jurisdiction, presence: true, inclusion: { in: ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"] }
	validates :act_type, presence: true, inclusion: { in: %w{Act Regulations} }
	validates :year, presence: true, numericality: {only_integer: true, greater_than: 1900, less_than_or_equal_to: Time.now.year}
	validates :number, presence: true, numericality: {only_integer: true, greater_than: 0}

	def parsed_content(file="AIA")
		result = []
		File.open(Rails.root+"legislation/test_parsed.txt", "rb").each_line do |line| 
			result.push parse_line(line)
		end
		result.delete_if { |line| line.blank? }
		return result
	end
	
	def parse_line(line)
		line.gsub!('<Part>',     					'<div class="Part">')
		line.gsub!('</Part>',    					'</div>')
		line.gsub!('<Section>', 					'<div class="Section">')
		line.gsub!('</Section>', 					'</div>')
		line.gsub!('<Definition>',  			'<div class="Definition">')
		line.gsub!('</Definition>', 			'</div>')
		line.gsub!('<Subs_1>',  				  '<div class="Subs_1">')
		line.gsub!('</Subs_1>', 				  '</div>')
		line.gsub!('<Subs_2>',  				  '<div class="Subs_2">')
		line.gsub!('</Subs_2>', 				  '</div>')
		line.gsub!('<Subs_3>',  				  '<div class="Subs_3">')
		line.gsub!('</Subs_3>', 				  '</div>')
		line.gsub!('<Subs_4>',  				  '<div class="Subs_4">')
		line.gsub!('</Subs_4>', 				  '</div>')
		line.gsub!('<Explanatory_box>',  	'<div class="Explanatory_box">')
		line.gsub!('</Explanatory_box>', 	'</div>')
		line.gsub!('<Note>',  				    '<p class="Note">')
		line.gsub!('</Note>', 						'</p>')
		line.gsub!('<Title>',  				    '<h2>')
		line.gsub!('</Title>', 						'</h2>')
		line.gsub!('<List>',  				    '<div class="List">')
		line.gsub!('</List>', 						'</div>')
		line.gsub!('<Definitions_List>',  '<div class="List no_indent_list">')
		line.gsub!('</Definitions_List>', '</div')
		line.gsub!('<List_intro>',		    '<div class="List_intro">')
		line.gsub!('</List_intro>', 			'</div>')
		line.gsub!('<List_item_no_indent>','<div class="List_item_no_indent">')
		line.gsub!('</List_item_no_indent>','</div>')
		line.gsub!('<Subheading>',				 '<p class="Subheading">')
		line.gsub!('</Subheading>',				 '</p>')
		line.gsub!('<Defined_term>',			 '<em><strong>')
		line.gsub!('</Defined_term>',			 '</strong></em>')
		return line
	end

	@@open_tags = []
	
	KEY   = 0
	VALUE = 1
	
	def self.subs_depth(num)
		puts "subs_depth trying to determine subsection depth of "+num.inspect
		num=num[0]
		case num
			when "0".."9"
				return SUBSECTION
			when "a".."z"
			if num=="i"
				return SUBPARAGRAPH #come back to this - sometimes i is roman, sometimes it's just an i
			else
				return PARAGRAPH
			end
			when "A".."Z"
			return UPPER_ALPHA
		end
	end
	
	def self.create_tag(params)
		result = params[:open_tag] ? "<" : "</"
		result += params[:tag].to_s + ">"
		indent = params[:indent] > 0 ? params[:indent] : 0
		return "  "*indent+result
	end
	
	def self.wrap_with_tag(str, tag)
		return create_tag(open_tag: true, tag: tag, indent: 0)+str+create_tag(open_tag: false, tag: tag, indent: 0)
	end
	
	
	def self.close_tag(output, tag)
		if tag.is_a? Integer
			output.puts create_tag(open_tag: false, tag: tag > SECTION ? 
				SUBSECTION_TAG+(tag - SECTION).to_s : 
			STRUCTURAL_REGEXES[tag][OUTER_TAG], indent: tag - START_INDENTING)
		else
			raise "don't know how to close this tag: "+tag.inspect
		end
	end

	def self.type_of_line(line)
		result = { type: NORMAL, matches: nil }
		# see if it's a structural element: Chapter, Division, etc
		STRUCTURAL_REGEXES.each do |array|
			matches = array[VALUE][REGEX].match line
			if matches
				result[:type]    = array[KEY]
				result[:matches] = matches
				break
			end
		end
		
		# if not, see if it's a subsection
		if !result[:matches]
			matches = SUBSECTION_REGEX.match line
			if matches
				result[:type]    = subs_depth(matches[CONTAINER_NO])
				result[:matches] = matches
			end
		end
		
		# see if it's a special type of paragraph: subheading or notes
		if !result[:matches]
			SINGLE_LINE_REGEXES.each do |array|
				matches = array[VALUE].match line
				if matches
					result[:type]    = array[KEY]
					result[:matches] = matches
					break
				end
			end
		end
		
		return result
	end
	
	def self.close_all_tags_lower_than(depth, output)
		
		# if current tag is a structural tag
		# always close previous structural tags up to and including the same depth
		
		if depth.is_a? Integer
			while @@open_tags.size>0 and @@open_tags.last >= depth
				puts "closing "+@@open_tags.last.to_s
				close_tag(output, @@open_tags.pop)
			end
		elsif depth==NORMAL or depth==NOTES
			if @@open_tags.last > SECTION
				puts "closing because new paragraph detected: "+@@open_tags.last.to_s
				close_tag(output, @@open_tags.pop)
			end
			# work out whether to close previous subsections or not
		elsif depth==SUBHEADING
			# close everything up to SECTION
			while @@open_tags.size>0 and @@open_tags.last > SECTION
			  puts "closing because subheading detected: "+@@open_tags.last.to_s
				close_tag(output, @@open_tags.pop)
			end
		end
	end
	
	def self.inline_matches(line)
		# look for inline tags like definitions, act references
		DEFINITIONS_REGEXES.each do | hash|
			matches = hash[:regex].match line
			if matches
				puts "definitions regex matched "+matches.inspect
				line = line.sub(matches[hash[:defined_term]], wrap_with_tag(matches[hash[:defined_term]], DEFINED_TERM))
				break
			end
		end
		# check for act names & ad hoc defined terms
		
		INLINE_REGEXES.each do |array|
			matches = array[1].match line
			if matches
				puts "array is "+array.inspect
				puts "matches is "+matches.inspect
				line=line.gsub(matches[1], wrap_with_tag(matches[1], array[0]))
			end
		end
		return line
	end
	
	def self.insert_structural_tags(structural_tags_to_open, output, type)
		structural_tags_to_open.each do |depth|
			if depth <= SECTION
				tag = STRUCTURAL_REGEXES[depth][OUTER_TAG]
			else
				tag=SUBSECTION_TAG+(depth - SECTION).to_s
			end
			output.puts      create_tag(open_tag: true, tag: tag, indent: depth - START_INDENTING)
			@@open_tags.push depth
		end		
	end
	
	def self.insert_single_line_tags(single_line_tags, line)
		single_line_tags.each do | tag |
			line = wrap_with_tag(line, tag)
		end
		return line
	end
	
	def self.parse
		File.open(Rails.root+"legislation/"+"test_parsed.txt", "w") do |output|
			f = File.open(Rails.root+"legislation/"+"test.txt", "r:UTF-8").each_line do |line|
				line=line.chomp
				next if line.blank?
				type = type_of_line(line)
				structural_tags_to_open = []
				single_line_tags = []
				
				########  DEBUG      ################
				return if line=="STOP"
				puts " "
				puts "inspecting "+line
				puts "type is "+type.inspect
				puts "@@open_tags is "+@@open_tags.inspect
				########  END DEBUG  #############
				
				if @@open_tags.size > 0
					close_all_tags_lower_than(type[:type], output)
				end
				
				# handle new structural elements, and incidental single line tags
				if type[:type].is_a? Integer  # if it's a structural line
					single_line_tags.push (type[:type] <= SECTION ? 
																     STRUCTURAL_REGEXES[type[:type]][INNER_TAG] : NORMAL )
					structural_tags_to_open.push type[:type]
				else
					single_line_tags.push (type[:type])
				end
				
				# handle defined terms and act references
				line = inline_matches(line)
				
				puts "structural tags to open are "+structural_tags_to_open.inspect
				puts "single line tags are "+single_line_tags.inspect
				
				insert_structural_tags(structural_tags_to_open, output, type)
				line = insert_single_line_tags(single_line_tags, line)
				
				indent = 0
				if @@open_tags.last and @@open_tags.last > START_INDENTING
					indent = @@open_tags.last - START_INDENTING
				end
				indent+=1
				output.puts "  "*indent+line
				# PENDING CODE - set up new database objects for new 'section' of the Act
			end
			# it's now EOF - close any open tags
			close_all_tags_lower_than(0, output)
		end
		
	end
	
end

