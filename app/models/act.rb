# encoding: UTF-8
# == Schema Information
#
# Table name: acts
#
#  id            :integer          not null, primary key
#  title         :string(255)
#  last_updated  :date
#  jurisdiction  :string(255)
#  updating_acts :text
#  subtitle      :string(255)
#  regulations   :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  act_type      :string(255)
#  year          :integer
#  number        :integer
#  published     :boolean
#
# Indexes
#
#  index_acts_on_year_and_number  (year,number)
#

# TODO LOW - more sophisticated working out whether (i) is an alphabetical element or a roman numeral

include Treat::Core::DSL

####################################################################
#   STRUCTURAL REGEXES                                             #
####################################################################

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
	has_many :comments,   :through => :containers
	
	has_many :scopes,     as: :scope,   class_name: "Metadatum"
	has_many :contents,   as: :content, class_name: "Metadatum", dependent: :destroy
	
	delegate :definitions,          to: :scopes
	delegate :internal_references,  to: :scopes
		
	validates :title,        presence: true
	validates :last_updated, presence: true
	validates :jurisdiction, presence: true, inclusion:    { in: ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"] }
	validates :act_type, 		 presence: true, inclusion:    { in: %w{Act Regulations} }
	validates :year,     		 presence: true, numericality: {only_integer: true, greater_than: 1900, less_than_or_equal_to: Time.now.year}
	validates :number,   		 presence: true, numericality: {only_integer: true, greater_than: 0}
	
	if Rails.env.development?
		attr_accessor :nlp_act, :open_containers
	end

	def create_container(level, content, number, special_type)

		result                     = Container.new
		result.act_id              = self.id
		
		if @open_containers.last
			result.parent_id         = @open_containers.last.id
		end
		
		result.level               = level
		result.content             = content
		result.number              = number
		result.special_paragraph   = special_type
		
		if level < TEXT
			@open_containers.push  result
		end
		
		puts "about to save "+result.inspect if DEBUG
		if !result.save
			raise result.errors.messages.inspect
		end
		return result
	end
	
	def last_paragraph_list_head
		return @open_containers.rindex { |container| container.level == PARA_LIST_HEAD }
	end
	
	def close_previous_container?(level)
		if @open_containers.size < 1
			return false
		end
		
		list = last_paragraph_list_head
		
		if !list
			# no paragraph lists are open - straightforward - just close things off until the deepest open container is higher than current
			if DEBUG
				puts "no list open; current level is "+level.to_s
				puts "last open container is level "+@open_containers.last.level.to_s+" with content "+@open_containers.last.content
			end
			return @open_containers.last.level >= level
		end
		
		# there's a list - what do we do?
		
		if level < PARA_LIST_HEAD
			# it's a structural element
			# if the new item's superior or equal to the list head's parent, close off the list 
			head_list = list
			while @open_containers[head_list-1].level >= PARA_LIST_HEAD
				head_list-=1
			end
			if level <= @open_containers[head_list-1].level
				if DEBUG
					puts "new section is superior to the open list - close the open list as well as the previous structural element"
					puts "open containers is:"
					@open_containers.each { |c| puts c.inspect }
				end
				
				@open_containers=@open_containers[0..head_list-2]
				return false
			end
			# if it isn't, then it's either a child of the list head, or of the previous item
			if DEBUG
				puts "need to decide whether this structural entity is direct child of the list or not" 
			end
			if @open_containers.last.level == PARA_LIST_HEAD
				if DEBUG 
					puts "it's a direct child of the list - returning false"
				end
				# this is the first child of a list head - it must belong to the list head
				return false
			else
				# fall back to normal rules - see if last item is deeper than new item or not
				if DEBUG
					puts "fallback - level is "+level.to_s+" and about to return "+ (@open_containers.last.level >= level).to_s
					puts "last container is "+@open_containers.last.inspect
				end
				return @open_containers.last.level >= level
			end
		elsif level == PARA_LIST_HEAD
			# if it's a paragraph list heading, assume that it should just open a new list
			# MAY NEED TO REVISIT
			return false
		else
			# it's a normal paragraph
			if @open_containers.last.level == PARA_LIST_HEAD
				# this is the first child of a list head - it must belong to the list head
				return false
			else
				# the paragraph heading has other children
				list_level = @open_containers[list+1].level
				if list_level == TEXT
					# shouldn't be possible - plain paragraphs shouldn't make it onto the @open_containers list
					raise 'a plain paragraph appeared in the open_containers queue'
				else
					# the list children are structural elements, and now we have a paragraph
					# should the paragraph be a child of the last structural element, or should it close off the list?
					
					# if the list header's parent is also a list, then assume we have to break off the inner list
					if @open_containers[list-1].level == PARA_LIST_HEAD
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
		level        = nil
		content      = nil
		number       = nil           
		special_type = nil
		if entity.type == :paragraph
			level   = TEXT
			content = entity.to_s
			special_type = entity.get(:special_type)
		elsif entity.type == :section
			level   = entity.get(:level)
			content = entity.title.to_s
			number  = entity.get(:number)
		else
			raise 'unknown entity type '+entity.inspect
		end
		
		# close off open containers that need to be closed
		puts " " if DEBUG
		puts "closing previous containers for "+content if DEBUG
		while close_previous_container?(level)
			@open_containers.pop
		end
		
		# create a new container for this element
		create_container(level, content, number, special_type)
		
		# recursively call this again for each child paragraph
		entity.paragraphs.each { |p| process_entity(p) if p != entity}
	end
	
	# TODO Medium: better way of traversing tree / finding definitions - current code hits DB way too much
	
	def recursive_definition_parse(node, task)
		node.each do |child, grandchildren|
			if task == :definitions
				child.parse_definitions
			elsif task == :anchors
				child.parse_anchors
			end
			recursive_definition_parse(grandchildren, task)
		end
	end
	
	def parse_tree(task)
		roots = self.containers.roots
		roots.each do |container|
			recursive_definition_parse(container.subtree.arrange, task)
		end
	end

	def parse
		
		@nlp_act = document Rails.root+'legislation/'+'test.txt'
		@nlp_act.chunk(:legislation)
		puts "chunked"
		
		@open_containers  = []
		@nlp_act.sections.each { |section| process_entity(section) }
		
		puts "moving onto second bit"
		puts "moving onto second bit"
		puts "moving onto second bit"
		puts "moving onto second bit"
		puts "moving onto second bit"
		puts "moving onto second bit"
		
		parse_tree :definitions
		parse_tree :anchors
	end
	
	def relevant_metadata
		# gather all relevant anchors
		# start with those with universal scope
		relevant_metadata = Metadatum.where(universal_scope:true)
		# add to it the metadata with scope being the entire Act
		if self.scopes.size > 0
			relevant_metadata.push self.scopes
		end
		
		return relevant_metadata
		
	end

	def self.from_string_lgd(string)
		Treat::Entities::Zone.check_encoding(string)
		
		dot = string.count('.!?')
		
		matches = nil
		level = nil
		STRUCTURAL_REGEXES.each do |array|
			matches = array[VALUE][REGEX].match string
			if matches
				level = array[KEY]
				break
			end
		end
		
		if matches
			puts "structural regex matched" if DEBUG
			result = Treat::Entities::Title.new(string)
			result.set :level, level
			result.set :number, matches[1]
			return result
		else
			puts "no structural regex " if DEBUG
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
