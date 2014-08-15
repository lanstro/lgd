# encoding: UTF-8

# TODO
# define order of [num, lower alpha, roman, capital alpha?]
# consider whether notes should be a structural element type?
# more sophisticated working out whether (i) is an alphabetical element or a roman numeral

include Treat::Core::DSL

DEBUG = false

####################################################################
#   STRUCTURAL REGEXES                                             #
####################################################################

# structural line types

CONTAINER_LEVELS = [nil, "Chapter", "Part", "Division", "Subdivision", "Section", "Subs_1", "Subs_2",
                    "Subs_3", "Subs_4", "Paragraph"]

CHAPTER          = 1
PART             = 2
DIVISION         = 3
SUBDIVISION      = 4
SECTION          = 5
SUBSECTION       = 6
PARAGRAPH        = 7
SUBPARAGRAPH     = 8
UPPER_ALPHA      = 9
TEXT             = 10

# structural REGEX explanations
# Chapter titles: in a string like 'Chapter xxx-yyyy' or 'Chapter xxx - yyy', extracts the xxx into variable 1 and yyyy into 2,
# Part titles: in a string like 'Part xxx-yyyy' or 'Part xxx - yyy', extracts the xxx into variable 1 and yyyy into 2,
# Section titles: in a string like 'ddww yyyyy', extracts ddww into variable 1 and yyyyy into variable 2
# Subsection titles: in a string like (xx) yyyy', extracts (xx) into variable 1 and yyyy into variable 2
# Notes and examples: matches whole line if the string starts with 'Note: ' or 'Example: '
# Subsection and lower matches things that start with 0 or more tabs, then things within ()s:
	# Subsection matches a number followed by optional letters
	# Paragraph matches lower case letters  - NEED CONFLICT RESOLUTION FOR (i)
	# Subparagraph matches roman numerals - NEED CONFLICT RESOLUTION FOR (i)
	# Upper Alpha matches upper case alphabeticals
# TEXT matches semicolons at the end of lines (so paragraphs that are headers for lists)

STRUCTURAL_REGEXES = {
	SECTION      => [ /\A(\d+\w*)\s+(.+)\Z/,                       "Section"     ],
	SUBSECTION   => [ /\A\t*\((\d+[a-zA-z]*)\)\s+(.+)\Z/,          "Subs_1"      ],
	PARAGRAPH    => [ /\A\t*\(([a-z]+)\)\s+(.+)\Z/,                "Subs_2"      ],
	SUBPARAGRAPH => [ /\A\t*\((M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3}))\)\s+(.+)\Z/i, "Subs_3" ],  # catches empty braces too - may need to account for that case,
	UPPER_ALPHA  => [ /\A\t*\(([A-Z]+)\)\s+(.+)\Z/,                "Subs_4"      ],
	TEXT         => [ /:\s*\z/,                                    "p"           ],  # this one has to come after all the subsection ones
	SUBDIVISION  => [ /(?<=\ASubdivision\s)\s*(\w*)[-—](.+)\Z/,    "Subdivision" ],
	DIVISION     => [ /(?<=\ADivision\s)\s*(\w*)[-—](.+)\Z/,       "Division"    ],
	PART         => [ /(?<=\APart\s)\s*(\w*)[-—](.+)\Z/ ,          "Part",       ],
	CHAPTER      => [ /(?<=\AChapter\s)\s*(\w*)[-—](.+)\Z/,        "Chapter",    ],
}

KEY   = 0
VALUE = 1

# indices for STRUCTURAL_REGEXES
REGEX = 0
TAG   = 1

# indices for strings matched by the structural regexes
FULL_STRING  = 0
CONTAINER_NO = 1
HEADING      = 2


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
	
	attr_accessor :nlp_act, :all_containers
	
	def create_container
		
		result                 = Container.new
		result.id=             @current_id               # massive potential for database concurrency issues - fix later
		result.act_id=         self.id
		result.parent_id=      @open_containers.last ? @open_containers.last.id : nil
		
		@current_id+=1
		return result
	end
=begin	
	def create_structural_container(type)
		result = create_container(type)
		result.container_type= CONTAINER_LEVELS[type[:type]]
		result.number=         type[:matches][CONTAINER_NO]
		@open_containers.push result
		@all_containers.push  result
		return result
	end
=end
	def create_container_with_content(depth, content)
		result = create_container
		result.container_type = CONTAINER_LEVELS[depth]
		result.content = content
		#result.number = 1
		@all_containers.push   result
		@open_containers.push  result
		return result
	end
	
	def remove_containers_lower_than(depth)
		while @open_containers.size > 0 and CONTAINER_LEVELS.index(@open_containers.last.container_type) >= depth
			@open_containers.pop
		end
	end
	
	def parse
		
		@nlp_act = document Rails.root+"legislation/"+"test.txt"
		@nlp_act.chunk(:legislation)
		#@nlp_act.apply(:segment, :tokenize)
		#f.apply(:segment, :tokenize, :category)
		
		@current_id = 1
		@open_containers = []
		@all_containers = []
		
		@nlp_act.sections.each do |section|
			# remove all open containers that are lower depth than this one
			
			if @open_containers.size > 0 and section.get(:depth) > 0
				remove_containers_lower_than(section.get :depth)
			end
			
			# if this section is a paragraph, work out whether previous containers do need to be closed
			
			# create a new container and put it into both arrays
			
			create_container_with_content(section.get(:depth), section.title.to_s)
			
			section.paragraphs.each { |p| create_container_with_content(TEXT, p.to_s) }
			
			
			
		end
		# save containers to database
		
		result = Container.import @all_containers, :validate=>false
		if result.failed_instances.size>0
			#raise result.failed_instances.inspect
		end
		
		return @all_containers
	end

	def self.from_string_lgd(string)
		Treat::Entities::Zone.check_encoding(string)
		
		dot = string.count('.!?')
		
		matches = nil
		depth = nil
		STRUCTURAL_REGEXES.each do |array|
			matches = array[VALUE][REGEX].match string
			if matches
				depth = array[KEY]
				break
			end
		end
		
		if matches
			result = Treat::Entities::Title.new(string)
			result.set :depth, depth
			return result
		#elsif dot && dot >= 1 && string.count("\n") > 0
		#	Treat::Entities::Section.new(string)
		else
			Treat::Entities::Paragraph.new(string)
		end
	end
	
	def display
		puts_child(@nlp_act)
	end
	
	def puts_child(root)
		if root.children.size > 0
			root.children.each do |child|
				puts_child(child)
			end
		else
			depth = root.get :depth
			if depth == nil
				depth = root.parent.get :depth
				if depth == nil
					depth = 0
				end
			end
			puts "  "*depth+root.to_s
			return "  "*depth+root.to_s
		end
	end
end

Treat::Workers::Processors::Chunkers.add(:legislation) do |entity, options={}| 
	entity.check_hasnt_children
	zones = entity.to_s.split("\n")
	current = entity
	zones.each do |zone|
		zone.strip!
		next if zone == ''
		c =Act.from_string_lgd(zone)
		if c.type == :title
			if current.type == :section
				current = current.parent
				current = entity << Treat::Entities::Section.new
			else
				current = entity << Treat::Entities::Section.new
			end
			current.set :depth, (c.get :depth)
			c.set :depth, nil
		end
		current << c
	end
end


=begin

		result = Container.import @all_containers, :validate=>true
		if result.failed_instances.size>0
			raise result.failed_instances.inspect
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

=end