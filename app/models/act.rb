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

CHAPTER          = 1
PART             = 2
DIVISION         = 3
SUBDIVISION      = 4
SECTION          = 5
SUBSECTION       = 6
PARAGRAPH        = 7
SUBPARAGRAPH     = 8
SUBSUBPARAGRAPH  = 9
PARA_LIST_HEAD   = 10
TEXT             = 11

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
	# Subsubparagraph matches upper case alphabeticals
# PARA_LIST_HEAD matches semicolons at the end of lines (so paragraphs that are headers for lists)

STRUCTURAL_REGEXES = {
	SECTION          => [ /\A(\d+\w*)\s+(.+)\Z/,                           "Section"     ],
	SUBSECTION       => [ /\A\t*\((\d+[a-zA-z]*)\)\s+(.+)\Z/,              "Subs_1"      ],
	# VERY IMPORTANT that SUBPARAGRAPH remains above PARAGRAPH
	SUBPARAGRAPH 	   => [ /\A\t*\(((xc|xl|l?x{0,3})(ix|iv|v?i{0,3}))\)\s+(.+)\Z/, "Subs_3" ],  # catches empty braces too - may need to account for that case in future
	PARAGRAPH        => [ /\A\t*\(([a-z]+)\)\s+(.+)\Z/,                    "Subs_2"      ],
	SUBSUBPARAGRAPH  => [ /\A\t*\(([A-Z]+)\)\s+(.+)\Z/,                    "Subs_4"      ],
	PARA_LIST_HEAD   => [ /:\s*\z/,                                        "p"           ],  # this one has to come after all the subsection ones
	SUBDIVISION      => [ /(?<=\ASubdivision\s)\s*([\w\.]*)[-——](.+)\Z/,    "Subdivision" ],
	DIVISION         => [ /(?<=\ADivision\s)\s*([\w\.]*)[-——](.+)\Z/,       "Division"    ],
	PART             => [ /(?<=\APart\s)\s*([\w\.]*)[-——](.+)\Z/ ,          "Part",       ],
	CHAPTER          => [ /(?<=\AChapter\s)\s*([\w\.]*)[-——](.+)\Z/,        "Chapter",    ],
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
#   SINGLE LINE REGEXES                                            #
####################################################################

# single line types
NOTE         = "Note"
EXAMPLE      = "Example"
SUBHEADING   = "Subheading"

SINGLE_LINE_REGEXES = {
	SUBHEADING => /(?<![\.:;,]|and|or)\s*\Z/ ,
	NOTE       => /\A\s*Note\s*:\s+(.*)\Z/,
	EXAMPLE    => /\A\s*Example\s*\d*\s*:\s+(.*)\Z/
}

# Subheading regex looks for any lines that don't end in a full stop, semicolon, colon or comma.  Must be 
# run after the subsection_regex, because a lot of subsections end in 'and', 'or' etc
# captures the subheading in item 1
# Notes regex looks for lines starting with 'Note:' or 'Example:' - captures that word in item 1 and the
# text in item 2
# list_intro is just the first line of all lists - doesn't need its own regex
# paragraph is the 'catch all'



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
	
	def create_container(depth, content, number, special_type)

		result                   = Container.new
		result.id                = @current_id               # massive potential for database concurrency issues - fix later
		result.act_id            = self.id
		result.parent_id         = @open_containers.last ? @open_containers.last.id : nil
		@current_id+=1
		
		result.depth             = depth
		result.content           = content
		result.number            = number
		result.special_paragraph = special_type
		@all_containers.push       result
		if depth < TEXT
			@open_containers.push  result
		end
		return result
	end
	
	def last_paragraph_list_head
		return @open_containers.rindex { |container| container.depth == PARA_LIST_HEAD }
	end
	
	def close_previous_container?(depth)
		if @open_containers.size < 1
			return false
		end
		
		list = last_paragraph_list_head
		
		if !list
			# no paragraph lists are open - straightforward - just close things off until the deepest open container is higher than current
			if DEBUG
				puts "no list open; current depth is "+depth.to_s
				puts "last open container is depth "+@open_containers.last.depth.to_s+" with content "+@open_containers.last.content
			end
			return @open_containers.last.depth >= depth
		end
		
		# there's a list - what do we do?
		
		if depth < PARA_LIST_HEAD
			# it's a structural element
			# if the new item's superior or equal to the list head's parent, close off the list 
			head_list = list
			while @open_containers[head_list-1].depth >= PARA_LIST_HEAD
				head_list-=1
			end
			if depth <= @open_containers[head_list-1].depth
				if DEBUG
					puts "new section is superior to the open list - close the open list as well as the previous structural element"
					puts "open containers is:"
				end
				@open_containers.each { |c| puts c.inspect }
				@open_containers=@open_containers[0..head_list-2]
				return false
			end
			# if it isn't, then it's either a child of the list head, or of the previous item
			if DEBUG
				puts "need to decide whether this structural entity is direct child of the list or not" 
			end
			if @open_containers.last.depth == PARA_LIST_HEAD
				if DEBUG 
					puts "it's a direct child of the list - returning false"
				end
				# this is the first child of a list head - it must belong to the list head
				return false
			else
				# fall back to normal rules - see if last item is deeper than new item or not
				if DEBUG
					puts "fallback - depth is "+depth.to_s+" and about to return "+ (@open_containers.last.depth >= depth).to_s
					puts "last container is "+@open_containers.last.inspect
				end
				return @open_containers.last.depth >= depth
			end
		elsif depth == PARA_LIST_HEAD
			# if it's a paragraph list heading, assume that it should just open a new list
			# MAY NEED TO REVISIT
			return false
		else
			# it's a normal paragraph
			if @open_containers.last.depth == PARA_LIST_HEAD
				# this is the first child of a list head - it must belong to the list head
				return false
			else
				# the paragraph heading has other children
				list_depth = @open_containers[list+1].depth
				if list_depth == TEXT
					# shouldn't be possible - plain paragraphs shouldn't make it onto the @open_containers list
					raise 'a plain paragraph appeared in the open_containers queue'
				else
					# the list children are structural elements, and now we have a paragraph
					# should the paragraph be a child of the last structural element, or should it close off the list?
					
					# if the list header's parent is also a list, then assume we have to break off the inner list
					if @open_containers[list-1].depth == PARA_LIST_HEAD
						@open_containers = @open_containers[0..list-1]
						return false
					else
					# otherwise, assume it's a child of the final element
						return false
					end
				end
			end
		end
	end
	
	def process_entity(entity)
		depth        = nil
		content      = nil
		number       = nil           
		special_type = nil
		if entity.type == :paragraph
			depth   = TEXT
			content = entity.to_s
			special_type = entity.get(:special_type)
		elsif entity.type == :section
			depth   = entity.get(:depth)
			content = entity.title.to_s
			number  = entity.get(:number)
		else
			raise 'unknown entity type '+entity.inspect
		end
		if !depth
			raise 'section without depth assigned '+entity.inspect
		end
		
		# close off open containers that need to be closed
		puts " "
		puts "closing previous containers for "+content
		while close_previous_container?(depth)
			@open_containers.pop
		end
		
		# create a new container for this element
		create_container(depth, content, number, special_type)
		
		# recursively call this again for each child paragraph
		entity.paragraphs.each { |p| process_entity(p) if p != entity}
	end
	
	def parse
		
		@nlp_act = document Rails.root+"legislation/"+"test.txt"
		@nlp_act.chunk(:legislation)
		#@nlp_act.apply(:segment, :tokenize)
		#f.apply(:segment, :tokenize, :category)
		
		@current_id = 1
		@open_containers = []
		@all_containers = []
		
		@nlp_act.sections.each { |section| process_entity(section) }
		# save containers to database
		result = Container.import @all_containers, :validate=>true
		
	end
	
	def self.html_same_line_tags(container)
		if container.depth <= SECTION
			return ['h2', '/h2']
		else
			if container.special_paragraph
				return ['p class='+container.special_paragraph, '/p']
			else
				return ['p', '/p']
			end
		end
	end
	
	def self.html_children_wrapper_tags(container)
		if container.depth < PARA_LIST_HEAD
			return ['div class=depth'+container.depth.to_s, '/div']
		end
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
			puts "structural regex matched" if DEBUG
			result = Treat::Entities::Title.new(string)
			result.set :depth, depth
			result.set :number, matches[1]
			return result
		else
			puts "no structural regex" if DEBUG
			result = Treat::Entities::Paragraph.new(string)
			special_type = nil
			SINGLE_LINE_REGEXES.each do |array|
				matches = array[VALUE].match string
				if matches
					special_type=array[KEY]
					break
				end
			end
			if special_type
				result.set :special_type, special_type
			end
		end
		return result
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
			current.set :depth,  (c.get :depth)
			current.set :number, (c.get :number)
			c.set :depth, nil
			c.set :number, nil
		end
		current << c
	end
end


=begin

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

HTML_TAGS = {
	CONTAINER_LEVELS[SECTION]    => ['<div class="Section">', '</div>'],
	SUBHEADING => ['<p class="Subheading">','</p>'],
	NOTES  => ['<p class="Note">','</p>'],
	NORMAL  => ['<p>','</p>'],
	TITLE  => ['<h2>','</h2>']
}

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