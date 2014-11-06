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
#  comlawID      :string(255)
#
# Indexes
#
#  index_acts_on_year_and_number  (year,number)
#

# TODO LOW - more sophisticated working out whether (i) is an alphabetical element or a roman numeral

include Treat::Core::DSL
include LgdLog

####################################################################
#   STRUCTURAL REGEXES                                             #
####################################################################

# structural REGEX explanations
# Chapter titles: in a string like 'Chapter xxx-yyyy' or 'Chapter xxx - yyy', extracts the xxx into variable 1 and yyyy into 2,
# Part titles: in a string like 'Part xxx-yyyy' or 'Part xxx - yyy', extracts the xxx into variable 1 and yyyy into 2,
# Section titles: in a string like 'ddww yyyyy', extracts ddww into variable 1 and yyyyy into variable 2
# Subsection titles: in a string like (xx) yyyy', extracts (xx) into variable 1 and yyyy into variable 2
# Subsection and lower matches things that start with 0 or more tabs, then things within ()s:
	# Subsection matches a number followed by optional letters
	# Paragraph matches lower case letters  - NEED CONFLICT RESOLUTION FOR (i)
	# Subparagraph matches roman numerals - NEED CONFLICT RESOLUTION FOR (i)
	# Subsubparagraph matches upper case alphabeticals
# PARA_LIST_HEAD matches semicolons at the end of lines (so paragraphs that are headers for lists)

STRUCTURAL_REGEXES = {
	SECTION          => [ /\A(\d+\w*)\s+(.+)\Z/,                                      "Section"     ],
	SUBSECTION       => [ /\A\t*\((\d+[a-zA-z]*)\)\s+(.+)\Z/,                         "Subs_1"      ],
	# VERY IMPORTANT that SUBPARAGRAPH remains above PARAGRAPH, as it loops through this in order, and several roman numeral sequences register under both regexes
	SUBPARAGRAPH 	   => [ /\A\t*\(((?:xc|xl|l?x{0,3})(?:ix|iv|v?i{0,3}))\)\s+(.+)\Z/, "Subs_3" ],  # catches empty braces too - may need to account for that case in future
	PARAGRAPH        => [ /\A\t*\(([a-z]+)\)\s+(.+)\Z/,                               "Subs_2"      ],
	SUBSUBPARAGRAPH  => [ /\A\t*\(([A-Z]+)\)\s+(.+)\Z/,                               "Subs_4"      ],
	PARA_LIST_HEAD   => [ /:\s*\z/,                                                   "p"           ],  # this one has to come after all the subsection ones
	SUBDIVISION      => [ /(?<=\ASubdivision\s)\s*([\w\.]*)[-——](.+)\Z/,              "Subdivision" ],
	DIVISION         => [ /(?<=\ADivision\s)\s*([\w\.]*)[-——](.+)\Z/,                 "Division"    ],
	PART             => [ /(?<=\APart\s)\s*([\w\.]*)[-——](.+)\Z/ ,                    "Part",       ],
	CHAPTER          => [ /(?<=\AChapter\s)\s*([\w\.]*)[-——](.+)\Z/,                  "Chapter",    ],
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
	has_many :flags, as: :flaggable, dependent: :destroy
	
	has_many :scopes,     as: :scope,   class_name: "Metadatum"
	has_many :contents,   as: :content, class_name: "Metadatum", dependent: :destroy
	
	# TODO LOW: consider doing a regex to check validity of comlawID
	delegate :definitions,          to: :scopes
	delegate :internal_references,  to: :scopes
		
	validates :title,        presence: true
	validates :last_updated, presence: true
	validates :jurisdiction, presence: true, inclusion:    { in: ["Commonwealth", "Victoria", "New South Wales", "Queensland", "Northern Territory", "Australian Capital Territory", "Western Australia", "South Australia", "Tasmania"] }
	validates :act_type, 		 presence: true, inclusion:    { in: %w{Act Regulations} }
	validates :year,     		 presence: true, numericality: {only_integer: true, greater_than: 1900, less_than_or_equal_to: Time.now.year}
	validates :number,   		 presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :comlawID,     presence: true
	
	if Rails.env.development?
		attr_accessor :nlp_act
	end

	def parse_tree(task)
		if task != :definitions and task != :anchors and task != :annotations
			return
		end
		roots = self.containers.roots
		roots.each do |container|
			recursive_tree_parse(container.subtree.arrange, task)
		end
	end

	def check_with_user(question)
		puts question+" (Y)es, (N)o"
		response = STDIN.gets
		if response[0].downcase != "y"
			return false
		end
		return true
	end
	
	def get_input_from_user(question)
		puts question+" (Y)es, (N)o"
		response = STDIN.gets
		if response[0].downcase != "y"
			return false
		end
		return true
	end
	
	def parse
		
		@update_act = false
		
		# TODO LOW - fix up the dialogue options for the start of this, consider making it web based
		
		if self.containers.size > 0
			
			return if !check_with_user "This Act has already been parsed in the past, with comlawID "+self.comlawID.to_s+".  Do you want to continue?"
				
			if !check_with_user "Is the file you wish to process an additional part of the Act that has not been processed before?"
				puts "I will process the file as an amended Act."
				@update_act=true
			end
				
			keep_looping = true
			while keep_looping
				puts "What is the comlawID of the file you'd like to process?  (Type 'quit', 'exit' or 'cancel' to return).  Leave blank if it's the same as the current ComlawID."
				response=STDIN.gets.strip
				if ["quit", "exit", "cancel"].include? response.downcase
					return
				end
				if response.downcase == self.comlawID.downcase
					puts "That seems to be the same document as what is already in the database.  Are you sure you want to continue? (Y)es, (N)o"
					confirmation = STDIN.gets
					if confirmation[0].downcase != "y"
						return
					end
				elsif response.length != 0
					puts "Thank you, comlawID now set to "+response
					puts "When did Comlaw publish "+response+"?  Format: dd/mm/yyyy"
					begin
						new_date = STDIN.gets.strip.to_date
						rescue ArgumentError
						puts "Invalid date."
					end
					if new_date < self.last_updated
						puts "That is an older version of the Act than the one in the database.  Exiting."
						return
					end
					self.last_updated = new_date
					self.comlawID = response
				end
				if self.valid?
					@update_act = true
					keep_looping=false
				else
					puts "Sorry, your input for the invalid.  Please start again."
					self.reload
				end
			end
			
		end
		keep_looping=true
		while keep_looping
			puts "which file would you like to parse? (Default is test.txt, 'exit' to quit)"
			files=Dir.glob(Rails.root+'legislation/*.txt').map { |f| File.basename(f, ".txt") }
			puts "files is "+files.inspect
			count = 0
			files.each do |f|
				puts "["+count.to_s+"] "+f
				count+=1
			end
			
			
			filename = STDIN.gets.strip
			
			if ARABIC_REGEX.match filename and files[filename.to_i]
				filename=files[filename.to_i]
			elsif filename.length==0
				filename="test"
			elsif ["quit", "exit", "cancel"].include? filename
				return
			elsif !files.include? filename
				puts "That was not in the list of filenames"
				next
			end
			keep_looping=false
			filename = Rails.root.join('legislation', filename+'.txt')
			puts "trying to open "+filename.to_s
			begin
				@nlp_act = document filename
				rescue Exception
					puts "Failed to open file.  Exiting."
					return
			end
		end
				
		@nlp_act.chunk(:legislation)
		log "chunked"
		
		@current_container = @update_act ? self.containers.roots.order("position ASC").first : nil
		@nlp_act.sections.each { |section| process_entity(section) }
		
		#parse_tree :definitions
		#parse_tree :anchors
		#parse_tree :annotations
		self.save
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

	private

		def stage_container(level, content, number, special_type, parent)

			result                     = Container.new
			result.act                 = self
			result.level               = level
			result.content             = content
			result.number              = number
			result.special_paragraph   = special_type
			result.parent              = parent
			return result
			
		end
		
		def commit_container(container, skip_save=false)
			if skip_save
				@current_container = @current_container.next_container
				# we're leaving the old @current_container alone by not saving it
				# so move it one container across
			else
				log "about to save "+container.inspect if DEBUG
				# how to tell whether to save the new container at the end of the current parent, or in front of the current_container?
				if @current_container and @current_container.next_container and @current_container.next_container.level == @current_container.level
					container.insert_at @current_container.position
					# we're inserting in front of the current_container
					# leave current_container where it is
				else
					container.save #saves to end of the current parent's children
					@current_container = container
					# we're inserting the new container at the end of the current parent, so make it the new current_container
				end
			end
			return container
		end
		
		def find_parent(level)
			
			return nil if !@current_container
			result = @update_act? @current_container.previous_container : @current_container
			
			while result
				if result.level == TEXT
					result=result.parent
					next
				end
				
				list = result.level == PARA_LIST_HEAD ? result : result.ancestors.where(level: PARA_LIST_HEAD).last
				log "should we close previous container?  New level is "+level.inspect+"\nCurrent container is #{@current_container.inspect}\nresult is #{result.inspect} and result's ancestors are #{result.ancestors.inspect}" if DEBUG
				
				if !list
					# no paragraph lists are open - straightforward - just close things off until the deepest open container is higher than current
					log "no list open; current level is "+level.to_s if DEBUG
					if level > result.level
						break
					else
						result=result.parent
						next
					end
				end
				
				# there's a list - what do we do?
				
				if level < PARA_LIST_HEAD
					# it's a structural element
					# if the new item is superior or equal to the list head's parent, close off the list 
					highest_list=list
					while highest_list.parent.level == PARA_LIST_HEAD
						highest_list=list.parent
					end
					if level <= highest_list.parent.level
						log "new section is superior to the open list's parent - close the open list, and then return true so that the open list's parent gets removed too"
						result = list.parent
						break
					end
					# if it isn't, then it's either a child of the list head, or of the previous item
					log "need to decide whether this structural entity is direct child of the list or not" if DEBUG
					if result == list
						log "it's a direct child of the list - returning false" if DEBUG 
						# this is the first child of a list head - it must belong to the list head
						break
					else
						# fall back to normal rules - see if last item is deeper than new item or not
						log "fallback - level is "+level.to_s+" and about to return "+ (result.level >= level).to_s+"\ncurrent container is "+result.inspect if DEBUG
						if level > result.level
							break
						else
							result=result.parent
							next
						end
					end
				elsif level == PARA_LIST_HEAD
					# if it's a paragraph list heading, assume that it should start a new sub-list and close the existing list
					# unless the PARA_LIST_HEAD is the first child of a structural element, and contains either the word 'outline' or
					# is a definitional zone, in which case we leave it alone
					# maybe better to get user input?
					if list.previous_container == list.parent
						if /[Oo]utline/.match list.content or list.is_definition_zone?
							break
						end
					end
					result=result.parent
					next
				elsif level == TEXT
					if list.children.size == 0 or # this is the first child of the list - it must belong to the list head
						list.children.first.level==level # the list's children are also paragraphs, so this paragraph presumably belongs in the list
						break
					else
						result=result.parent
						next
					end
				end
			end
			return result
		end
		
		def process_entity(entity, skip_save=false)
			
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
				content = entity.get(:strip_number)
				if !content
					content=entity.title.to_s
				end
				number  = entity.get(:number)
			else
				raise 'unknown entity type '+entity.inspect
			end
			
			log "\n\n" if DEBUG
			log "processing entity "+content+"\nlevel: "+level.inspect+"\nnumber: "+number.inspect if DEBUG
			
			# find the right parent for the new container
			
			parent = find_parent(level)
			new_container = stage_container(level, content, number, special_type, parent)
			
			if @update_act
				#@current_container = @current_container.next_container
				log "considering @current_container of "+@current_container.inspect if DEBUG
				log "against #{new_container.inspect}" if DEBUG
				compare = @current_container <=> new_container
				
				while @current_container and compare < 0 
					# the container currently being processed is higher precedence than what's in the database, so what's in the database has been deleted
					flag = @current_container.flags.create(category: "Delete", comment: "deleted by "+self.comlawID)
					flag.save
					@current_container = @current_container.next_container
					compare = @current_container <=> new_container
				end
				
				if @current_container and compare == 0  # ie it's the same container
					if @current_container.content == content
						log "Not adding this object as it is already in database:\nContent: "+content+"\nLevel: "+level.to_s+"\nNumber: "+number.to_s+"\nExisting container: "+@current_container.inspect
					else
						log "overwriting this object:\nContent: "+content+"\nLevel: "+level.to_s+"\nNumber: "+number.to_s+"\nExisting container: "+@current_container.inspect
						@current_container.content           = content
						@current_container.annotated_content = nil
						@current_container.definition_parsed = nil
						@current_container.references_parsed = nil
						@current_container.annotation_parsed = nil
						@current_container.save
						raise "new content saved"
					end
					skip_save=true
				end
				
				if !skip_save
					raise "new section detected"
				end
			end
			# save the container
			commit_container(new_container, skip_save)
			# recursively call this again for each child paragraph
			entity.paragraphs.each { |p| process_entity(p, skip_save) if p != entity}
		end
		
		# TODO Medium: better way of traversing tree / finding definitions - current code hits DB way too much
		
		# should be private
		def recursive_tree_parse(node, task)
			node.each do |child, grandchildren|
				if task == :definitions
					child.parse_definitions
				elsif task == :anchors
					child.parse_anchors
				elsif task == :annotations
					child.recalculate_annotations
				end
				recursive_tree_parse(grandchildren, task)
			end
		end
		
		
		# should be private
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
				log "structural regex matched" if DEBUG
				result = Treat::Entities::Title.new(string)
				result.set :level, level
				result.set :number, matches[1]
				result.set :strip_number, matches[2]
				return result
			else
				log "no structural regex " if DEBUG
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
