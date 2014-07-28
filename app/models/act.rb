# encoding: UTF-8

# TODO
# define order of [num, lower alpha, roman, capital alpha?]
# consider whether notes should be a structural element type?
# more sophisticated working out whether (i) is an alphabetical element or a roman numeral

DEBUG = true

####################################################################
#   STRUCTURAL REGEXES                                             #
####################################################################

# structural line types
CONTAINER_LEVELS = [nil, "Chapter", "Part", "Division", "Subdivision", "Section", "Subs_1", "Subs_2",
                    "Subs_3", "Subs_4"]

CHAPTER          = 1
PART             = 2
DIVISION         = 3
SUBDIVISION      = 4
SECTION          = 5
SUBSECTION       = 6
PARAGRAPH        = 7
SUBPARAGRAPH     = 8
UPPER_ALPHA      = 9

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

KEY   = 0
VALUE = 1

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
NORMAL       = "Paragraph"
SUBHEADING   = "Subheading"
TITLE        = "Title"

HTML_TAGS = {
	CONTAINER_LEVELS[SECTION]    => ['<div class="Section">', '</div>'],
	SUBHEADING => ['<p class="Subheading">','</p>'],
	NOTES  => ['<p class="Note">','</p>'],
	NORMAL  => ['<p>','</p>'],
	TITLE  => ['<h2>','</h2>']
}

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
	has_and_belongs_to_many :collections
	validates :title, presence: true
	validates :last_updated, presence: true
	validates :jurisdiction, presence: true, inclusion: { in: ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"] }
	validates :act_type, presence: true, inclusion: { in: %w{Act Regulations} }
	validates :year, presence: true, numericality: {only_integer: true, greater_than: 1900, less_than_or_equal_to: Time.now.year}
	validates :number, presence: true, numericality: {only_integer: true, greater_than: 0}

	def parse
		
		@all_containers=[]
		@open_containers=[]
		
		Container.delete_all(:act_id => self.id)
		
		@current_id=1
		
		if Container.count > 0
			@current_id = Container.maximum(:id)+1
		end
		
		f = File.open(Rails.root+"legislation/"+"test.txt", "r:bom|UTF-8").each_line do |line|
			line=line.chomp
			next if line.blank?
			type = type_of_line(line)
			########  DEBUG      ################
			if line=="STOP"
				puts "stopping: @all_containers is:"
				@all_containers.each do |container|
					puts container.inspect
				end
				result = Container.import @all_containers, :validate=>true
				if result.failed_instances.size>0
					raise result.failed_instances.inspect
				end
				return
			end
			
			if DEBUG
				puts " "
				puts "inspecting "+line
				puts "type is "+type.inspect
				puts "@open_containers is "+@open_containers.inspect
			end
			########  END DEBUG  #############
			
			
			structural_tags_to_open = []
			single_line_tags = []
			
			if @open_containers.size > 0
				remove_containers_lower_than(type[:type])
			end
			
			# handle new structural elements
			if type[:type].is_a? Integer  # if it's a structural line
				create_structural_container(type)
				if type[:type] <= SECTION
					create_container_with_content(STRUCTURAL_REGEXES[type[:type]][INNER_TAG], line)
				else
					create_container_with_content(NORMAL, line)
				end
			else
				create_container_with_content(type[:type], line)
			end
			
			# handle defined terms and act references
			check_definitions(line)
			
			if DEBUG
				puts "structural tags to open are "+structural_tags_to_open.inspect
				puts "single line tags are "+single_line_tags.inspect
			end
			
		end
		# it's now EOF - close any open tags
		@all_containers.each do |container|
			puts container.inspect
		end
		result = Container.import @all_containers, :validate=>true
		if result.failed_instances.size>0
			raise result.failed_instances.inspect
		end
	end
	
	def create_container(type)
		
		result                 = Container.new
		result.id=             @current_id               # massive potential for database concurrency issues - fix later
		result.act_id=         self.id
		result.parent_id=      @open_containers.last ? @open_containers.last.id : nil

		@current_id+=1
		return result
	end
	
	def create_structural_container(type)
		result = create_container(type)
		result.container_type= CONTAINER_LEVELS[type[:type]]
		result.number=         type[:matches][CONTAINER_NO]
		@open_containers.push result
		@all_containers.push  result
		return result
	end
	
	def create_container_with_content(type, line)
		result = create_container(type)
		result.container_type = type
		result.content = line
		result.number = 1
		@all_containers.push   result
		return result
	end
	
	def remove_containers_lower_than(type)
		if type.is_a? Integer
			while @open_containers.size > 0 and CONTAINER_LEVELS.index(@open_containers.last.container_type) >= type
				@open_containers.pop
			end
		else
			if type == SUBHEADING
				while @open_containers.size > 0 and CONTAINER_LEVELS.index(@open_containers.last.container_type) > SECTION
					@open_containers.pop
				end
			elsif type == NOTES or type == NORMAL# come back to
				while @open_containers.size > 0 and CONTAINER_LEVELS.index(@open_containers.last.container_type) > SECTION
					@open_containers.pop
				end
			else
				raise "strange type of container type: "+type.inspect
			end
		end
	end
	
	def subs_depth(num)
		puts "subs_depth trying to determine subsection depth of "+num.inspect if DEBUG
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
	
	def type_of_line(line)
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
	
	def check_definitions(line)
		
		# find if there's an open definitions list
		# if there is, record the scope
		
		# every time there is a term being defined, start a definition object
		# 
		
		# look for inline tags like definitions, act references
		DEFINITIONS_REGEXES.each do | hash|
			matches = hash[:regex].match line
			if matches
				puts "definitions regex matched "+matches.inspect  if DEBUG
				line = line.sub(matches[hash[:defined_term]], wrap_with_tag(matches[hash[:defined_term]], DEFINED_TERM))
				break
			end
		end
		# check for act names & ad hoc defined terms
		
		INLINE_REGEXES.each do |array|
			matches = array[1].match line
			if matches
				puts "array is "+array.inspect if DEBUG
				puts "matches is "+matches.inspect if DEBUG
				line=line.gsub(matches[1], wrap_with_tag(matches[1], array[0]))
			end
		end
		return line
	end
	
	
	def insert_single_line_tags(single_line_tags, line)
		single_line_tags.each do | tag |
			line = wrap_with_tag(line, tag)
		end
		return line
	end
	
	def self.html_tags(container)
		return HTML_TAGS[container.container_type]
	end

end

