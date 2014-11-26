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

ROMAN_CATCH_ALL = 1000

STRUCTURAL_REGEXES = {
	SECTION          => [ /\A(\d+\w*)\s+(.+)\Z/,                                      "Section"     ],
	SUBSECTION       => [ /\A\t*\((\d+[a-zA-z]*)\)\s+(.+)\Z/,                         "Subs_1"      ],
	# VERY IMPORTANT that SUBPARAGRAPH remains above PARAGRAPH, as it loops through this in order, and several roman numeral sequences register under both regexes
	SUBPARAGRAPH 	   => [ /\A\t*\(((?:xc|xl|l?x{0,3})(?:ix|iv|v?i{0,3}))\)\s+(.+)\Z/, "Subs_3"      ], # catches empty braces too - may need to account for that case in future
	PARAGRAPH        => [ /\A\t*\(([a-z]+)\)\s+(.+)\Z/,                               "Subs_2"      ],
	SUBSUBPARAGRAPH  => [ /\A\t*\(([A-Z]+)\)\s+(.+)\Z/,                               "Subs_4"      ],
	ROMAN_CATCH_ALL  => [ /\A\t*\((.+?)\)\s+(.+)\Z/,                                  "Subs_3"      ], # if it has braces and can't match any of the proper regexes, it's probably one of those stupid amended romans like ivb
	PARA_LIST_HEAD   => [ /:\s*\z/,                                                   "p"           ],  # this one has to come after all the subsection ones
	SUBDIVISION      => [ /(?<=\ASubdivision\s)\s*([\w\.]*)[-——-](.+)\Z/,              "Subdivision" ],
	DIVISION         => [ /(?<=\ADivision\s)\s*([\w\.]*)[-——-](.+)\Z/,                 "Division"    ],
	PART             => [ /(?<=\APart\s)\s*([\w\.]*)[-——-](.+)\Z/ ,                    "Part",       ],
	CHAPTER          => [ /(?<=\AChapter\s)\s*([\w\.]*)[-——-](.+)\Z/,                  "Chapter",    ],
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
	NOTE       => /\A\s*Note( \d)?\s*:\s+(.*)\Z/,
	EXAMPLE    => /\A\s*Example( \d)?\s*:\s+(.*)\Z/
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
	
	has_many :flags, through: :containers
	
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
		
	
	def first_container
		return nil if self.containers.count == 0
		
		return self.containers.roots.first
	end
	
	def last_container
		return nil if self.containers.count == 0
		result = self.containers.roots.last
		while result.children.size > 0
			result = result.children.last
		end
		return result
	end
	
	def self.find_act(string)
		# TODO MEDIUM: make this more sophisticated
		return Act.find_by(title: string)
	end
	
	def find_container(str, reference_container=nil)
		
		# can handle 3 types of formats for string:
		# 1. structural_word number (eg: section 3, subsection 35(3), paragraph (v))
		# 2. structural_wordNumber (eg s3, ss33, Pt1, etc)
		# 3. just straight out number (eg 33, 34(a), etc)
		
		# reference_container required if it's a relative reference
		
		return nil if str.count('(') > str.count(')')
		str = str.split(' ')
		return nil if str.size > 2 or str.size==0
		
		if str.size == 2
			level = Container.alias_to_level(str.first)
			return nil if !level or level >= PARA_LIST_HEAD # can't find just general paragraphs
			str=str[1]
		else
			str=str[0]
			if str[0]!="("
				# delete up to two leading s's
				str = str[1..-1] if str[0].downcase == 's'
				str = str[1..-1] if str[0].downcase == 's'
				return nil if !str[0].between?('0', '9')
			end
		end
		
		# where we've been explicitly told what level the target is, maybe we can
		# find it quickly via absolute reference
		
		# section and chapter numbers are unique - can just look straight for them 
		if level and level <= SECTION
			results = self.containers.where(level: level, number: str)
			return results.first if results.size == 1
		end
		
		# split the number up into an array, where each element of the array is the content of a set of parentheses
		
		numbers = str.split(/[()]/).delete_if(&:blank?)
		log "numbers is "+numbers.inspect if DEBUG
		first_number = numbers.shift
		
		if numbers.size == 0 and level
			first_level = level
		else
			first_level  = Container.number_to_level first_number
		end
		
		log "first_level is "+first_level.to_s
		
		# we need to find the subtree that contains the entire reference, then
		# recursively go down the subtree and narrow it down using each reference along the way
		# amongst the parent's children by using its number
		
		if str[0] != '('
			# it's an absolute reference starting with the section number - fairly easy job to find the right subtrees
			root = self.containers.where(level: SECTION, number: first_number).first
			return nil if !root
		# otherwise, need a reference point to work out which of the multiple containers with this number it's
		# talking about
		elsif !reference_container
			return nil
		else
			# it's a relative reference
			# first, see if it's in the reference container's exact ancestry line
			if first_level < reference_container.level
				root = reference_container.ancestors.where(number: first_number).first
			elsif first_level == reference_container.level
				root=reference_container.siblings.where(number: first_number).first
			else
				root=reference_container.subtree.where(number: first_number).first
			end
			log "root after first set of checks is "+root.inspect if DEBUG
			if !root
				# if not, find the ancestor that has a level immediately above this number
				puts "no parent found, need to go to ancestors' siblings" if DEBUG
				best_ancestor = reference_container.ancestors.where("level < ?", first_level).max_by(&:level)
				log "best_ancestor is "+best_ancestor.inspect if DEBUG
				return nil if !best_ancestor # weird
				root = best_ancestor.subtree.where(number: first_number).first
			end
		end
		
		log "final root is "+root.inspect if DEBUG
		
		while numbers.size>0
			puts 
			new_number = numbers.shift
			root = root.subtree.where(number: new_number).first
			return nil if !root
		end
		return root
	end
	
	def parse
		
		# TODO LOW - fix up the dialogue options for the start of this, consider making it web based
		
		if self.containers.size > 0
			
			return if !check_with_user "This Act has already been parsed in the past, with comlawID "+self.comlawID.to_s+".  Do you want to continue?"
				
			result = get_comlawID_and_date
			while !result[:complete]
				result = get_comlawID_and_date
			end
			return if !result[:continue]
		end
		
		while get_filename
		end
				
		@nlp_act.chunk(:legislation)
		log "chunked"
		
		@current_container = find_current_container
		
		process_entity(@nlp_act.sections[0], true)
		ActiveRecord::Base.logger.level = 1
		@nlp_act.sections[1..-1].each { |section| process_entity(section) }
		
		#parse_tree :definitions
		#parse_tree :anchors
		#parse_tree :annotations
		ActiveRecord::Base.logger.level = 0
		self.save
	end
	
	def relevant_metadata
		# gather all relevant anchors
		# start with those with universal scope
		relevant_metadata = Metadatum.where(universal_scope:true)
		# add to it the metadata with scope being the entire Act
		if self.scopes.size > 0
			relevant_metadata += self.scopes
		end
		return relevant_metadata
	end

	private

		def stage_container(params)

			result                     = Container.new
			result.act                 = self
			result.level               = params[:level]
			result.content             = params[:content]
			result.number              = params[:number]
			result.special_paragraph   = params[:special_paragraph]
			result.parent              = params[:parent]
			return result
			
		end
		
		def commit_container(container, skip_save=false)
			if skip_save
				# we're leaving the old @current_container alone by not saving it
			else
				container.calculate_definition_zone
				log "about to save "+container.inspect if DEBUG
				# how to tell whether to save the new container at the end of the current parent, or in front of the current_container?
				if @current_container and @current_container.next_container and @current_container.next_container.level == @current_container.level
					container.insert_at @current_container.position
					# we're inserting in front of the current_container
					# leave current_container where it is
				else
					container.save #saves to end of the current parent's children
					@current_container = container.reload
					# we're inserting the new container at the end of the current parent, so make it the new current_container
				end
			end
			return container
		end
		
		def find_parent(new_container)
			
			log "looking for parent for "+new_container.inspect+"\n@current_container is "+@current_container.inspect if DEBUG
			
			return nil if !@current_container
			
			result = @current_container
			
			level = new_container.level

			# starting from the current_container, loop up the chain of ancestry until we find the
			# appropriate parent
			while result
			
				log "is the current result the right container?  It is #{result.inspect}" if DEBUG
				
				# plain paragraphs can't be parents of anything other than notes and examples
				if result.level == TEXT and ![NOTE, EXAMPLE].include? new_container.special_paragraph
					result=result.parent
					next
				end
				
				# parentage rules are different depending on whether there's a massive paragraph-led list
				# however, sections and higher structural elements are never children of lists - just do a straight out level comparison
				if level <= SECTION
					if level > result.level
						break
					else
						result=result.parent
						next
					end
				end
				
				# list is the most immediate paragraph list item in the parentage chain
				list = result.level == PARA_LIST_HEAD ? result : result.ancestors.where(level: PARA_LIST_HEAD).last
				
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
				
				# work out what the highest list is, as we want to know whether we're working under a definitional list or an Act outline

				# different rules depending on what the new container's level is
				highest_list=list
				while highest_list.parent.level == PARA_LIST_HEAD
					highest_list=list.parent
				end
				if level < PARA_LIST_HEAD
					# it's a structural element
					# if the new item is superior or equal to the highest list head's parent, close off the list 
					if level <= highest_list.parent.level
						log "new container is superior to the highest list's parent - move the current result to the highest list's parent, and go to next" if DEBUG
						result = list.parent
						next
					end
					# if it isn't, then it's either a child of the list head, or of the previous item
					log "need to decide whether this structural entity is direct child of the list or not" if DEBUG
					if result == list
						log "new container is a direct child of the list" if DEBUG 
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
					# the new container is a paragraph list heading
					# if the list is the first child of a structural element, and the list either:
						# contains the word 'outline' or
						# is a definitional zone, 
					# then we let that be the parent
					# otherwise, assume that it should start a new sub-list and close the existing list
					# maybe better to get user input?
					if list.previous_container == list.parent
						if /[Oo]utline/.match list.content or list.is_definition_zone?
							break
						end
					end
					result=result.parent  # maybe this should be result = list.parent; break
					next
				elsif level == TEXT
					if result==list and list.children.size == 0 # this is the first child of the list - it must belong to the list head
						break
					elsif (new_container.content and ["and", "but", "is ", "as "].include? new_container.content[0..2]) or
								[NOTE, EXAMPLE].include? new_container.special_paragraph
						# if the new container starts with these words, 
						# or if it's a note or an example
						# then it's not a fresh list item
						if result.parent == list
							# if the current candidate for parent is a direct child of the list, then the new
							# container must be its child
							break
						else
							# otherwise, lines starting with 'and' or 'but' tend to not belong to its immediate
							# predecessor, but instead to that one's parent
							result = result.parent
							break
						end
					elsif highest_list.is_definition_zone?
						if new_container.content.include? "mean" or 
					     new_container.content.include? "includ" or
							 new_container.content.include? ": see" or
							 /[-——-] ?see/.match new_container.content or
							 (new_container.content.index(': ') and new_container.content.index(': ') < 30) # some acts are lazy with definitions, they just go xxx: definition of xxx
							# the new container is a new definition, and its parent should be the highest list item
							result = highest_list
							break
						elsif result==highest_list  # it's a definitional zone, the current container is a paragraph, the lowest item is the definitional list, so that has to be the parent
							break
						else
							# get user input
							
							log "User choosing a parent for "+new_container.inspect+"\nCurrent result was "+result.inspect if DEBUG
							result = choose_parent(result, new_container, list, highest_list)
							log "User chose "+result.inspect if DEBUG
							break
						end
					elsif result==list and list.children.first.level==level # the list's children are also paragraphs, so this paragraph presumably belongs in the list
						break
					else
						result=result.parent
						next
					end
				end
			end
			return result
		end

		def choose_parent(result, new_container, list, highest_list)
			
			puts "\nFrom the last list, the content has been: "
			current=list
			count=0
			while current and current.content != new_container.content and count < 10
				puts current.content_with_number
				current=current.next_container
				count += 1
			end
			puts "\nThe current content is:\n"+new_container.content+"\n"
			puts "\nWhich of the following is its parent?"
			choices=result.ancestors.reverse
			choices.unshift result
			index = choices.index(highest_list)
			choices = choices[0..index]
			count = 0
			choices.each do |c|
				puts "["+count.to_s+"] ("+c.long_citation+") "+c.content
				count+=1
			end
			print 7.chr
			print ">>"
			choice = STDIN.gets.strip
			if DECIMAL_REGEX.match choice and choices[choice.to_i]
				choice=choices[choice.to_i]
			elsif choice.length==0
				choice = choices.first
			else
				choice = choices.find { |c| c.number == choice }
				if !choice
					print "That was not in the list of choices.  Please choose again.\n>>"
					return choose_parent(result, new_container, list, highest_list)
				end
			end
			return choice
		end
		
		def process_entity(entity, first=false)
			
			level             = nil
			content           = nil
			number            = nil           
			special_paragraph = nil
			if entity.type == :paragraph
				level             = TEXT
				content           = entity.to_s
				special_paragraph = entity.get(:special_paragraph)
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

			new_container = stage_container(level: level, content: content, number: number, special_paragraph: special_paragraph)
			
			new_container.parent = first ? nil : find_parent(new_container)
			
			log "considering new_container of "+new_container.inspect if DEBUG
			puts "\nconsidering new_container of "+new_container.inspect if DEBUG
			log "against #{new_container.inspect}" if DEBUG
			
			if !first and @current_container
				@current_container=@current_container.next_container
			end
			compare = @current_container <=> new_container
			while @current_container and compare < 0 
				# the container currently being processed is higher precedence than what's in the database, so what's in the database has to be deleted
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
				end
				skip_save=true
			end
			
			# raise "no skip_save" if !skip_save
							
			# save the container
			commit_container(new_container, skip_save)
			# recursively call this again for each child paragraph
			entity.paragraphs.each { |p| process_entity(p) if p != entity}
		end
		
		# TODO Medium: better way of traversing tree / finding definitions - current code hits DB way too much
		
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
					log "structural regex match for string "+string+" of level "+array[KEY].to_s
					level = array[KEY]
					level = SUBPARAGRAPH if level == ROMAN_CATCH_ALL
					break
				end
			end
			
			if matches
				result = Treat::Entities::Title.new(string)
				result.set :level, level
				result.set :number, matches[1]
				result.set :strip_number, matches[2]
				log "structural regex matched: "+result.inspect if DEBUG
				return result
			else
				log "no structural regex " if DEBUG
				result = Treat::Entities::Paragraph.new(string)
				special_paragraph = nil
				SINGLE_LINE_REGEXES.each do |key, regex|
					matches = regex.match string
					if matches
						special_paragraph=key
						break
					end
				end
				if special_paragraph
					result.set :special_paragraph, special_paragraph
				end
			end
			return result
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
			puts question+" (Type 'quit', 'exit' or 'cancel' to return)"
			response = STDIN.gets.strip
			if ["quit", "exit", "cancel"].include? response.downcase
				return "exit"
			end
			return response
		end
		
		def get_comlawID_and_date
			
			response = get_input_from_user "What is the comlawID of the file you'd like to process?  Leave blank if it's the same as the current ComlawID."
			
			if response.downcase == self.comlawID.downcase
				return {complete: true, continue: false} if !check_with_user "That seems to be the same document as what is already in the database.  Are you sure you want to continue? (Y)es, (N)o"
			elsif response.length != 0
				puts "Thank you, comlawID now set to "+response
				response = get_input_from_user "When did Comlaw publish "+response+"?  Format: dd/mm/yyyy"
				new_date = response.to_date
				if new_date < self.last_updated
					puts "That is an older version of the Act than the one in the database.  Exiting."
					return {complete: true, continue: false}
				end
				self.last_updated = new_date
				self.comlawID = response
			end
			if self.valid?
				return {complete: true, continue: true}
			else
				puts "Sorry, your input for the invalid.  Please start again."
				self.reload
				return {complete: false}
			end
		end
		
		def get_filename
			
			puts "Which file would you like to parse? (Press enter for test.txt)"
			files=Dir.glob(Rails.root+'legislation/*.txt').map { |f| File.basename(f, ".txt") }
			count = 0
			files.each do |f|
				puts "["+count.to_s+"] "+f
				count+=1
			end
			
			filename = STDIN.gets.strip
			
			if DECIMAL_REGEX.match filename and files[filename.to_i]
				filename=files[filename.to_i]
			elsif filename.length==0
				filename="test"
			elsif ["quit", "exit", "cancel"].include? filename
				return false
			elsif !files.include? filename
				puts "That was not in the list of filenames"
				return true
			end
			filename = Rails.root.join('legislation', filename+'.txt')
			puts "trying to open "+filename.to_s
			@nlp_act = document filename
			return false
		end
		
		def find_current_container
			
			# if the act hasn't been parsed before, then no need for a current_container
			
			return nil if self.containers.size == 0
			
			nlp_sections = @nlp_act.sections
			
			# grab the first section from @nlp_act, and find the matching container
			first_entity = nlp_sections.first
			level   = first_entity.get(:level)
			number  = first_entity.get(:number)
			
			puts first_entity.inspect
			puts "level is "+level.inspect
			puts "number is "+number.inspect
			
			if !level or !number or level > SECTION
				raise "File is incompatible.  Please make sure the file starts with a section or higher."
			end
			
			result = self.containers.where(level: level, number: number).first
			
			# if there's an exact match, then make that the @next_container
			puts "found a current_container "+result.inspect if result
			return result if result
			
			# there's no exact match - see if we should just tack this whole thing onto the end
			first_entity = stage_container(level: level, number: number)
			
			if (last_container <=> first_entity) < 0
				return nil
			end
			
			raise "Please submit a new file that either overlaps an existing section, or can all fit at the end of the currently processed Act."

		end
end
