# encoding: UTF-8
# == Schema Information
#
# Table name: containers
#
#  id                :integer          not null, primary key
#  number            :text
#  last_updated      :date
#  updating_acts     :text
#  regulations       :integer
#  created_at        :datetime
#  updated_at        :datetime
#  act_id            :integer
#  content           :text
#  level             :integer
#  special_paragraph :string(255)
#  position          :integer
#  ancestry          :string(255)
#  ancestry_depth    :integer
#  annotated_content :text
#  definition_parsed :datetime
#  references_parsed :datetime
#  annotation_parsed :datetime
#
# Indexes
#
#  index_containers_on_act_id_and_number  (act_id,number)
#  index_containers_on_ancestry           (ancestry)
#

####################################################################
#   DEFINITIONS AND CROSS REFERENCES                               #
####################################################################

SCOPE_REGEX =    /[Ii]n(( this| any)? (\w+)( [\diI]+\w*(\(\w+\))?)?)[,:-]/
PURPOSES_REGEX = /[Ff]or the purposes of(( this| any)? (\w+)( [\diI]+\w*(\(\w+\))?)?)[,:-]/

# for both regexes:
# match group 1 is the whole scope, ie 'this Act', 'section 2', etc
# match group 2 is 'this' or 'any' - optional
# match group 3 is the structural tag, ie 'Act', 'section', etc - always there
# match group 4 is is the number, ie '34', '(b)' - optional

REGEX_WHOLE_SCOPE     = 1
REGEX_STRUCTURAL_NAME = 3

ARABIC_REGEX = /\A[0-9]+\Z/
ROMAN_REGEX  = /\A(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})\Z/i
ITAA97_REMAINDER_REGEX = /\A[-——]\s?([0-9]+)\Z/
ARABIC_START_REGEX = /\A([0-9]+)(.+)?/

PARAGRAPH_SIMILARITY_THRESHOLD = 0.8

class Container < ActiveRecord::Base
	
	include LgdLog
	
	has_ancestry orphan_strategy: :destroy, cache_depth: true
	acts_as_list scope: [:ancestry]
	default_scope -> {order('position ASC')} 
	
	belongs_to :act
	has_many :comments, dependent: :destroy
	
	has_many :scopes,     as: :scope,   class_name: "Metadatum"
	has_many :contents,   as: :content, class_name: "Metadatum", dependent: :destroy
	
	has_many :annotations, dependent: :destroy
	has_many :flags, as: :flaggable, dependent: :destroy
	
	validates :act, presence: true
	validates :level, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :regulations, numericality: {only_integer: true, greater_than: 0}, :allow_blank => true  # TODO MEDIUM: this is not right - regulations needs to be a formal relation
	
	@definition_zone = nil
	
	before_destroy :check_descendants_also_being_destroyed
	after_destroy :flag_metadata_with_no_scope
	
	def check_descendants_also_being_destroyed
		# if children are not all getting destroyed, then return false
		survivors = self.descendants.delete_if { |d| d.flags.where(category: "Delete").size > 0 }
		raise "Cannot delete "+self.inspect+"\nas not all of its descendants are flagged for deletion:\n"+survivors.inspect
		# TODO MEDIUM - instead of raising an error, maybe just run through them 1 by 1 and ask user to confirm they're to be deleted?
	end
	
	def flag_metadata_with_no_scope
		# if any metadata has this container as its scope, give it a human check flag with comment "seems to be no scope left"
		Metadatum.where(scope_type: "Container", scope_id: self.id).each do |m|
			flag = m.flags.create(category: "Review", comment: "The scope of this metadatum has been deleted, perhaps it should also be delted?")
			flag.save
		end
	end
	
	
	if Rails.env.development?
		attr_accessor :nlp_handle, :mp, :ip, :sp
	end
	
	attr_accessor :definition_zone

	################################################################
	#																															 #
	#   Helpers, for everyday querying                             #
	#																															 #
	################################################################
	
	def type
		result = STRUCTURAL_ALIASES[self.level][0]
		return self.level < SECTION ? result : result.downcase
	end
	
	def names
		if self.level >= PARA_LIST_HEAD
			return nil
		end
		result = []
		num = self.level < SECTION ? self.number : subsection_citation
		num_start = /\d/.match(num[0]) ? true : false
		
		STRUCTURAL_ALIASES[self.level].each do |name|
			result.push name+" "+num
			if num_start
				result.push name+num
			end
		end
		result.push num
		return result
	end
	
	def citation
		
		if self.level == CHAPTER
			return self.type+" "+self.number
		elsif self.level < SECTION
			current=self
			result=[]
			while current and current.level >= PART
				result.push self.type+" "+self.number
				current = current.parent
			end
			return result.join(" ,")
		else 
			start  = ""
			result = ""
			if self.level >= PARA_LIST_HEAD
				start = "text in "
				current = self.parent
				while current.level >= PARA_LIST_HEAD
					current=current.parent
				end
			else
				current=self
			end
			return start+=current.type+" "+subsection_citation(current)
		end
	end
	
	def short_content
		if content.length < 60
			return content
		else
			return content[0..45]+"... "+content[-15..-1]
		end
	end
	
	def next_container
		return nil if self.new_record?
		result=self.children.order("position ASC").first
		return result if result
		
		current = self
		
		while current
			return current.lower_item if current.lower_item
			current=current.parent
		end
		
		return nil
		
	end
	
	def previous_container
		return nil if self.new_record?
		result = self.higher_item
		return result if result
		return self.parent
	end

	def <=>(other)
		
		# 0 means it's the same container
		# -1 means self comes earlier in an Act than other
		# +1 means self comes later in the Act than other
		
		puts "<=> is comparing "+self.inspect+"\nagainst "+other.inspect
		
		return 0 if self==other
		
		if self.act_id != other.act_id
			raise "Containers belong to different Acts.  Cannot compare."
		end
		
		if self.ancestry == other.ancestry
			self_path, other_path = [], []
		else
			self_path  =  self.ancestors
			other_path = other.ancestors
			
			if self_path.where(level: SECTION).size > 0 and other_path.where(level: SECTION).size > 0
				# if they both have an ancestor that is a section, that section should be unique in an act, and you can compare
				# ancestries from there, saving a few queries
				self_path.delete_if { |c| c.level < SECTION }
				other_path.delete_if{ |c| c.level < SECTION }
			end
			
			while self_path.size>0 and other_path.size > 0
				result = self_path.shift <=> other_path.shift
				return result if result != 0
			end
		end
		# either both paths are identical, or one of them has run out
		if self_path.size == 0 and other_path.size == 0
			# self and other have identical ancestries - just compare their positions
			if self.position and other.position
				return self.position <=> other.position
			end
			return Container.compare_without_position(self, other)
		elsif self_path.size == 0
			if self.position and other_path.first.position
				result = self.position <=> other_path.first.position
			else
				result = Container.compare_without_position(self, other_path.first)
			end
			return result if result != 0
			# if we're here, it means other is a child of self, so it must be later in the act
			return -1
		else
			if self_path.first.position and other.position
				result = self_path.first.position <=> other.position
			else
				result= Container.compare_without_position(self_path.first, other)
			end
			return result if result != 0
			# if we're here, it means self is a child of other, so it must be later in the act
			return 1
		end
	end

	# processing annotations and recalculating the annotated_content
	
	def recalculate_annotations
		text=self.content.dup
		
		annotations=self.annotations.order("position ASC")
		
		# check that the positions given by the annotation and the words there are all correct
		# if they are, put down a 3 character marker "{*}"
		start_marker = "{*}"
		finish_marker = "{-}"
		marker_positions=[]
		
		annotations.delete_if do |annotation|
			start  = annotation.position
			finish = annotation.position + annotation.anchor.length-1
			
			start_modified  = start
			finish_modified = finish
			
			marker_positions.each do |p|
				if p < start_modified
					start_modified+=3
				end
				if p < finish_modified
					finish_modified+=3
				end
			end

			log "start is "+start.to_s+" and start_modified is "+start_modified.to_s
			log "finish is "+finish.to_s+" and finish_modified is "+finish_modified.to_s
			if self.content[start..finish] == annotation.anchor
				log "processing annotations: matched anchor and text: #{annotation.anchor}" if DEBUG
				text.insert(finish_modified+1, finish_marker)
				text.insert(start_modified,    start_marker)
				marker_positions.push start_modified, finish_modified+1
				log "partially prepared annotation looks like "+text if DEBUG
				next false
			else
				log "processing annotations: no match" if DEBUG
				log "anchor text is "+annotation.anchor+" and found text is "+self.content[start..finish] if DEBUG
				flag = annotation.flags.create(category: "Relete", comment: "failed to find the anchor when processing this flag.  Container content was "+self.content)
				flag.save
				warn "failed to find anchor position while recalculating annotation for "+self.content+":\nstart position is "+start.to_s+" and end position is "+finish.to_s+"\nannotation details wrong - annotation is "+annotation.inspect+" and container is id: "+self.id.to_s+" with text: "+self.content
				next true
			end
		end
		
		log "half prepared annotation looks like "+text if DEBUG
		
		# annotate the content
		
		annotations.each do |annotation|
			text.sub!(start_marker,  annotation.open_tag)
			text.sub!(finish_marker, annotation.close_tag)
		end
		self.annotated_content = text
		self.annotation_parsed = Time.now
		if !self.save
			warn "container failed to save after recalculating annotated content.  "+container.inspect+"\nErrors were: "+self.errors.inspect
		end
	end
	
	
	################################################################
	#																															 #
	#   Methods used in parsing the container                      #
	#																															 #
	################################################################
	
	
	def initialize_nlp
		if !@nlp_handle
			@nlp_handle = paragraph self.content
			@nlp_handle.apply(:segment, :tokenize, :stem)
		end
	end
	
	# finding definitions
	#####################
	
	def parse_definitions
		initialize_nlp
		if is_definition_zone? or (self.parent and self.parent.is_definition_zone?)
			process_definitions
		end
	end
	
	def process_definitions
		
		@nlp_handle.apply(:parse)
		
		#     TODO HIGH
		#			- parse_definitions needs to take into account existing definitions:
		#			- if different outcome from what was already there, flag the ones that might need to be removed
		#			- flag all the annotations linked to the flagged metadata
		#			- if not:
		#       - insert it into the right bit of the structure
		
		@mp = highest_phrases_with_word_or_stem(@nlp_handle.phrases, "mean", true)
		
		# exclude where 'means' is used as a noun
		@mp.delete_if do |p|
			means = p.words.find{ |w| w.to_s.downcase=="means"}
			if means 
				means.category
				next means.get(:category) == "noun"  # effectively means 'return means.get(:category) == "noun"'
			end
		end
		if @mp.size>0
			log "wrapping @mp phrases "+@mp.inspect+" " if DEBUG
			wrap_defined_terms(@mp)
			return
		end
		
		@ip = highest_phrases_with_word_or_stem(@nlp_handle.phrases, "includ", true)
		
		if @ip.size>0
			log "wrapping @ip phrases "+@ip.inspect+" " if DEBUG
			wrap_defined_terms(@ip)
			return
		end
		
		@sp = highest_phrases_with_word_or_stem(@nlp_handle.phrases, "see", false)
		# exclude 'Note: see'
		@sp.delete_if do |p|
			para = p.ancestor_with_type(:zone)
			index = para.words.index { |w| w.to_s.downcase == "see" }
			if !index or index==0 or para.words[index-1].to_s.downcase == 'note'
				next true
			end
			next false
		end
		if @sp.size > 0
			log "wrapping @sp phrases "+@sp.inspect+" " if DEBUG
			wrap_defined_terms(@sp)
		end
	end
	
	def definition_section_heading?
		initialize_nlp
		words = @nlp_handle.words
		if words.size > 3       # TODO LOW - make more sophisticated
			return false
		end
		return words.any?  { |w| w.stem.downcase == "definit" or w.to_s.downcase == "dictionary" }
	end
	
	def is_definition_zone?
		if @definition_zone != nil
			return @definition_zone[:is_definition] 
		end
		initialize_nlp
		if self.level <= SECTION
			@definition_zone = {is_definition: definition_section_heading? }
			return @definition_zone[:is_definition]
		end
		match_scope    =    SCOPE_REGEX.match self.content.to_s
		match_purposes = PURPOSES_REGEX.match self.content.to_s
		if match_scope and STRUCTURAL_FEATURE_WORDS.include? match_scope[REGEX_STRUCTURAL_NAME].downcase
			@definition_zone = {is_definition: true,
			scope:         match_scope[REGEX_WHOLE_SCOPE]}
			return true
		elsif match_purposes and STRUCTURAL_FEATURE_WORDS.include? match_purposes[REGEX_STRUCTURAL_NAME].downcase
			@definition_zone = {is_definition: true,
			scope:         match_purposes[REGEX_WHOLE_SCOPE]}
			return true
			# if the heading or title of this section is dictionary or definit*
		elsif definition_section_heading?
			@definition_zone = {is_definition: true }
			return true
		else
			parent=self.parent
			if parent and parent.is_definition_zone?
				@definition_zone = {is_definition: true,
				scope: 			   parent.definition_scope}
				return true
			end
		end
		# treat same as previous sibling
		previous = self.higher_item
		if previous
			@definition_zone = {is_definition: previous.is_definition_zone? ,
			scope:         previous.definition_scope}
		end
		@definition_zone = { is_definition: false }
		return false
	end
	
	def definition_scope
		if !@definition_zone
			is_definition_zone?
		end
		return @definition_zone[:scope]
	end
	
	
	def entity_includes_stem_or_word?(e, s, stem=true, downcase=true)
		if stem
			if downcase
				e.words.any? { |w| w.stem.downcase==s }
			else
				e.words.any? { |w| w.stem==s }
			end
		else
			if downcase
				e.words.any?{ |w| w.to_s.downcase == s }
			else
				e.words.any?{ |w| w.to_s == s }
			end
		end
	end
	
	def highest_phrases_with_word_or_stem(phrases, pattern, stem=true)
		result = phrases.find_all do |p| 
			if !entity_includes_stem_or_word?(p, pattern, stem) or
				(p.parent.type == :phrase and entity_includes_stem_or_word?(p.parent, pattern, stem))
				next false
			end
			next true
		end
		return result
	end
	
	def create_definition(params)
		
		d = Metadatum.new(category: "Definition")
		d.anchor = [params[:anchor]]
		d.content=self
		scope = translate_scope @definition_zone[:scope]
		if scope[:universal_scope]
			d.universal_scope = true
		else
			d.scope = scope[:scope]
		end
		if !d.save
			warn "definition failed to save "+d.inspect+"\nErrors were "+d.errors.inspect
		end
		return d
	end
	
	def wrap_defined_terms(definition_phrases)
		definition_phrases.each do |p| 
			log "wrapping "+p.to_s+" " if DEBUG
			index = p.position-1
			log "index is "+index.to_s
			if index==-1
				# maybe that means we should be finding one more level up?
				if p.parent and p.parent.parent
					p=p.parent
				else
					# weird - give up
					# TODO low - should probably log to see what kind of phrases cause this
					next
				end
			end
			# look for the previous phrase, and assume that is the defined term
			siblings=p.parent.children
			
			while index > 0 and siblings[index].type != :phrase
				index-=1
			end
			log "siblings[index] is "+siblings[index].to_s+" and index is "+index.to_s+" and inspect is "+siblings[index].inspect+" and its children are "+siblings[index].children.inspect if DEBUG
			
			if siblings[index].words.size == 1
				word = siblings[index].words.first
				# reject if coordinating conjunction (eg 'and'), determiner (eg 'the') 
				if word.tag== "CC" or word.tag=="DT"
					next
				end
			end
			
			subject_words = siblings[index].to_s
			metadatum = create_definition anchor: subject_words
			create_annotation category: "Defined_term", anchor: subject_words, position: self.content.index(subject_words)
		end
	end
	
	# finding anchors
	#####################
	
	def parse_anchors
		process_anchors
	end
	
	def process_anchors
		
		# TODO HIGH: need to do something about existing anchors
		
		if self.level <= SECTION
			return
		end
		
		# find definitional anchors
		
		relevant_metadata = self.act.relevant_metadata
		# then add anything with scope == this item or its parents
		current = self
		
		while current != nil
			current.scopes.each do |meta|
				relevant_metadata.push meta
			end
			current=current.parent
		end
		
		relevant_metadata.each do |meta|
			next if meta.content == self
			meta.anchor.each do |anchor|
				if /\b#{anchor}\b/.match self.content
					# exclude any anchors that are a subset of an existing metadatum anchor
					if self.contents.any? { |content | content.anchor.any? { |a| /\b#{anchor}\b/.match a } }
						next
					end
					log "trying to make a new annotation with anchor "+anchor+", index of "+self.content.index(anchor).to_s if DEBUG
					create_annotation anchor: anchor, position: self.content.index(/\b#{anchor}\b/), metadatum: meta
				end
			end
		end
		
		# find Act reference anchors
		
		words=self.content.split(" ")
		indices = words.each_index.select{ |i| words[i] == 'Act' }
		
		indices.each do |i|
			if words[i+1] and words[i+1].to_i > 0
				last_word_index = i+1
			else
				next
			end
			first_word_index = nil
			current=i-2
			while current > 0 
				if words[current].downcase == 'the'
					first_word_index=current+1
					break
				end
				current-=1
			end
			next if !first_word_index
			act_words=words[first_word_index..last_word_index].join(" ")
			create_annotation anchor: act_words, position: self.content.index(act_words), category: "Placeholder"
		end
		
		# TODO HIGH: find all 'acts', 'Chapters', 'Parts', etc and metadata them
	end
		
	def translate_scope(scope_string)
		log "translating "+scope_string.inspect+" into a scope" if DEBUG
		scope_string.strip!.downcase!
		result = {}
		if scope_string == "any act"
			result[:universal_scope] = true
		else
			result[:universal_scope] = false
			p = scope_string.gsub("/[.,]/", "").split(" ")
			if p[0] == "this"
				if !STRUCTURAL_FEATURE_WORDS.include?(p[1])
					info "trying to translate scope, found the word 'this', but don't know what type of structural term this is "+scope_string
				end
				if p[1] == "act"
					result[:scope] = this.act
				else
					parent = self.ancestors.find_by(level: Container.alias_to_level(p[1]))
					if !parent
						warn "trying to translate scope, couldn't find parent for "+self.inspect+".  Was looking for a level "+level.to_s
					end
					result[:scope] = parent
				end
			else
				# deal with when it's something like "section xxx"
				if !STRUCTURAL_FEATURE_WORDS.include?(p[0])
					info "trying to translate scope but don't know what type of reference this is: "+p.words.join(" ")
				end
				level = Container.alias_to_level(p[0])
				if !p[1]
					info "trying to translate scope, weird structural term without a number reference: "+scope_string
				end
				# TODO High: write the following code
				# if the level is higher than SECTION, then just look in the Act for that level with that number
				# else
				# if no braces or just one set of braces, then look for that number
				# if multiple braces, break then up into an array
				# if there's a number in front of the first brace, then that's the section number in the current Act
				# go down the chain of braces and pull out the relevant subtrees at each point
				# if no number, scope it to the current section
				# do the same thing
				
				# TODO HIGH - following line is a placeholder to be rewritten
			  info "trying to translate scope, got to unstructured reference \nContainer is "+self.inspect+"\n and content is "+self.content+"\n and scope string is "+scope_string
				result[:scope] = self
			end
		end
		return result
	end
	
	
	def create_annotation(params)
		a=self.annotations.build
		a.position  = params[:position]
		a.anchor    = params[:anchor]
		if params[:metadatum]
			a.metadatum=params[:metadatum]
			a.category="Metadatum"
		else
			a.category=params[:category]
		end
		if !a.save
			# flag the metadata for review
			flag = self.flags.create(category: "Review", comment: "anchor based on this failed "+a.inspect)
			flag.save
		end
	end
	
	
	
	################################################################
	#																															 #
	#   Class methods                                              #
	#																															 #
	################################################################
	
	def self.alias_to_level(word)
		log "converting "+word.inspect+" to a level" if DEBUG
		word_capitalized = word
		word_capitalized[0] = word_capitalized[0].capitalize
		level = nil
		STRUCTURAL_ALIASES.each do | key, aliases|
			if aliases.include? word or aliases.include? word_capitalized
				level = key
				break
			end
		end
		if !level
			return "couldn't find structural term for "+word
		end
		return level
	end
	
	#######################################################################
	#																															        #
	#   Methods for moving siblings around - acts_as_list / ancestry      #
	#																															        #
	#######################################################################
		
	def move_to_child_of(reference_instance)
		transaction do
			remove_from_list
			self.update_attributes!(:parent => reference_instance)
			add_to_list_bottom
			save!
		end
	end
	
	def move_to_left_of(reference_instance)
		transaction do
			remove_from_list
			reference_instance.reload # Things have possibly changed in this list
			self.update_attributes!(:parent_id => reference_instance.parent_id)
			reference_item_position = reference_instance.position
			increment_positions_on_lower_items(reference_item_position)
			self.update_attribute(:position, reference_item_position)
		end
	end
	
	def move_to_right_of(reference_instance)
		transaction do
			remove_from_list
			reference_instance.reload # Things have possibly changed in this list
			self.update_attributes!(:parent_id => reference_instance.parent_id)
			if reference_instance.lower_item
				lower_item_position = reference_instance.lower_item.position
				increment_positions_on_lower_items(lower_item_position)
				self.update_attribute(:position, lower_item_position)
			else
				add_to_list_bottom
				save!
			end
		end   
	end

	
	private
		
		def subsection_citation(current=self)
			if current.level >= PARA_LIST_HEAD or current.level < SECTION
				return nil
			end
			result = ""
			while current.level > SECTION
				if current.number
					result = "("+current.number+")" + result
				end
				current=current.parent
			end
			result = current.number+result
			return result
		end
		
		
		def self.to_roman(str)
			str = str.downcase
			str.tr!("ivxlcdm", "0123456")  # translate into numbers
			level, last, deviated, ret = 7, 0, false, 0
			table = [1,5,10,50,100,500,1000]  # the translation table
			str.each_char do |char|
				num = char.to_i
				if num > level  # means a deviation
					ret -= table[last]*2 # remedy deviation
					level = last-1 # don't allow IXI or IXV etc.
					deviated = true
				else
					deviated = false
					level = num  # don't allow MLM etc.
				end
				ret += table[num]
				last = num
			end
			ret
		end
		
		def self.compare_romans(first, second)
			
			# TODO MEDIUM - need to handle shit like Pt IVA - slice it up into two, then feed the alphabetical bits off to the compare_alphabetical_numbers method, much like how compare_arabic currently does it
			
			puts "compare_romans comparing "+first.to_s+" and "+second.to_s
			
			return compare_arabic_numbers(to_roman(first), to_roman(second))
		end
		
		def self.compare_alphabetical_numbers(first, second)
			
			puts "compare_alphabetical_numbers comparing "+first.to_s+" and "+second.to_s
			
			if first.length==1 and second.length==1
				return first<=>second
			elsif first.length == 0
				return 1
			elsif second.length == 0
				return -1
			elsif (first=="aa" and second=="a") or (first=="a" and second=="aa")
				puts "comparing an aa against an a - which one is higher?"
				result = STDIN.gets.strip
				if result == "aa"
					return first=="aa" ? -1 : 1
				else
					return first=="aa"? 1: -1
				end
				# see whether there's already an a or aa around
				# otherwise, get user input
			else
				result = compare_alphabetical_numbers(first[0], second[0])
				if result != 0
					return result
				else
					return compare_alphabetical_numbers(first[1..-1], second[1..-1])
				end
			end	
		end
		
		
		def self.compare_paragraphs(first, second)
			
			puts "compare_paragraphs comparing "+first.inspect+" and "+second.inspect
			
			if first.content==second.content
				return 0
			elsif first.parent.is_definition_zone? and second.parent.is_definition_zone?
				# if in definition section, compare alphabetically
				# compare word for word 3 times, then ask the user for input
				
				first_phrase  = first.content.split(' ')
				second_phrase = second.content.split(' ')
				index = 0
				
				while index < 3
					result = first_phrase[index].downcase <=> second_phrase[index].downcase
					return result if result != 0
					index+=1
				end
				return 0
				# TODO MEDIUM: maybe should go to user input here
				
			elsif first.content.pair_distance_similar(second.content) > PARAGRAPH_SIMILARITY_THRESHOLD
				return 0
			else
				# search following containers for a match until it's no longer a paragraph
				# if there's a match, return -1 because the current container has been deleted and the program needs to skip ahead to the matched one
				# otherwise, return 1, because it's a new paragraph that's been inserted
				next_container = first.next_container
				while next_container and next_container.level >= PARA_LIST_HEAD
					if next_container.content.pair_distance_similar(second.content) > PARAGRAPH_SIMILARITY_THRESHOLD
						return -1
					end
					next_container = next_container.next_container
				end
				next_container = second.next_container
				while next_container and next_container.level >= PARA_LIST_HEAD
					if next_container.content.pair_distance_similar(first.content) > PARAGRAPH_SIMILARITY_THRESHOLD
						return 1
					end
					next_container = next_container.next_container
				end
				puts "two dissimilar paragraphs being compared - what to do?"
				# TODO MEDIUM: consider whether to ask for user input here - right now it just returns 1 to signify that
				# 'first' is later in the act than 'second'
				return 1
			end
		end
		
	
		def self.compare_without_position(first, second)
			
			# this method assumes that one or both of first and second has no ancestry
			
			puts "comparing without position "+first.inspect+"\n against "+second.inspect
			
			# if we're here, we've already determined that these two elements have the same ancestors, and one of them
			# has no children.  That one also has no position, which means it hasn't been saved into the DB yet
			
			# so this is purely a comparison of their 'numbers', and if they don't have numbers, then their paragraph texts
			
			if first.level != second.level and (first.number or second.number)
				# ie, if the two containers are different levels, and they're not both paragraphs
				# assume the one that's a higher structural element is higher up in the Act
				return first.level <=> second.level
			end
			
			is_roman = (first.level == SUBPARAGRAPH) or (first.level == PART and ROMAN_REGEX.match first.number[0])
			
			if is_roman
				result= compare_romans(first.number, second.number)
			elsif [SECTION, SUBSECTION, CHAPTER, DIVISION, PART].include? first.level
				result= compare_arabic_numbers(first.number, second.number)
			elsif [PARAGRAPH, SUBSUBPARAGRAPH, SUBDIVISION].include? first.level
				result= compare_alphabetical_numbers(first.number, second.number)
			else
				result= compare_paragraphs(first, second)
			end
			puts "compare without position about to return "+result.to_s
			return result 
		end
		
		
		def self.compare_arabic_numbers(first, second)
			
			puts "compare_arabic_numbers comparing "+first.to_s+" and "+second.to_s
			
			if ARABIC_REGEX.match first.to_s+second.to_s
				puts "both are numbers and the compare is "+(first.to_i <=> second.to_i).to_s
				return first.to_i <=> second.to_i
			end
			
			first_remainder, second_remainder = "", ""
			
			match = ARABIC_START_REGEX.match first
			first          = match[1].to_i
			first_remainder= match[2].strip if match[2]
			
			match = ARABIC_START_REGEX.match second
			second          = match[1].to_i
			second_remainder= match[2].strip if match[2]
			
			if first != second
				puts "first is not the same as second"
				return first <=> second
			end
			
			is_ITAA97 = false
			match = ITAA97_REMAINDER_REGEX.match first_remainder
			if match
				first_remainder = match[1]
				is_ITAA97 = true
				puts "first remainder is ITAA97 - #{first_remainder}"
				puts match.inspect
			end
			match = ITAA97_REMAINDER_REGEX.match second_remainder
			if match
				second_remainder = match[1] if match
				is_ITAA97 = true
				puts "second remainder is ITAA97 - #{second_remainder}"
				puts match.inspect
			end
			
			if first_remainder.length == 0
				# something like s27 vs (s27-25 or s27A) - s27 wins
				return 1
			elsif second_remainder.length == 0
				return -1
			elsif is_ITAA97
				return compare_arabic_numbers(first_remainder, second_remainder)
			else
				return compare_alphabetical_numbers(first_remainder, second_remainder)
			end
		end
		
		

		
end
