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
#  definition_zone   :boolean
#
# Indexes
#
#  container_uniqueness                   (content,act_id,ancestry,number,position) UNIQUE
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

ARABIC_REGEX 						= /\A[0-9]+\Z/
ROMAN_REGEX 						= /\A(?:X{0,3})(?:IX|IV|V?I{0,3})\Z/i
ITAA97_REMAINDER_REGEX  = /\A[-——]\s?([0-9]+)\Z/
ARABIC_START_REGEX 			= /\A([0-9]+)(.+)?/

PUNCTUATION 			= [",",";",".",":"]
LIST_CONJUNCTIONS = ["and", "or", "to"]

PARAGRAPH_SIMILARITY_THRESHOLD = 0.8

ANNOTATION_START_MARKER 	= "{*}"
ANNOTATION_FINISH_MARKER  = "{-}"

DEFINITION_PARSING_STRATEGIES = { "mean" =>   { stem: true,  filter_method: :reject_mean_phrase? },
																	"includ" => { stem: true,  filter_method: nil },
																	"see" =>    { stem: false, filter_method: :reject_see_phrase? } }

WORD_BOUNDARY_REPLACEMENT_FRONT='(?<=^|\s|[.,;:])'
WORD_BOUNDARY_REPLACEMENT_BACK= '(?=\s|$|[.,;:])'
																	
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
	
	validates :content, uniqueness: { scope: [:act_id, :ancestry, :number, :position], message: "A container with the same ancestry, number and content already exists." }
	
	before_destroy :check_descendants_also_being_destroyed
	after_destroy :flag_metadata_with_no_scope
	
	if Rails.env.development?
		attr_accessor :nlp_handle, :mp, :ip, :sp
	end
	
	
	################################################################
	#																															 #
	#   Activerecord callbacks                                     #
	#																															 #
	################################################################
	
	def save_and_check_dependencies(params)
		# params are passed straight from controller, in turn from an admin submitting an update
		self.assign_attributes(params)
		changes = self.changes
		if self.save
			if changes[:content]
				parse_definitions
				recalculate_annotations
			end
			return true
		else
			return false
		end
	end
	
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
	
	################################################################
	#																															 #
	#   Helpers, for everyday querying                             #
	#																															 #
	################################################################
	
	def type
		result = STRUCTURAL_ALIASES[self.level][0]
		return self.level < SECTION ? result : result.downcase
	end
	
	def aliases
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
	
	def long_citation
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
	
	################################################################
	#																															 #
	#   Comparison with other containers in the same Act           #
	#																															 #
	################################################################

	def <=>(other)
		
		# 0 means it's the same container
		# -1 means self comes earlier in an Act than other
		# +1 means self comes later in the Act than other
		
		return 0 if self==other
		
		return nil if self.act_id != other.act_id
		
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
				text.insert(finish_modified+1, ANNOTATION_FINISH_MARKER)
				text.insert(start_modified,    ANNOTATION_START_MARKER)
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
			text.sub!(ANNOTATION_START_MARKER,  annotation.open_tag)
			text.sub!(ANNOTATION_FINISH_MARKER, annotation.close_tag)
		end
		if text.include? ANNOTATION_START_MARKER or text.include? ANNOTATION_FINISH_MARKER
			f = self.flags.build(category: "Review", comment: "the calculated annotation has leftover annotation markers: "+text)
			f.save
			warn "the calculated annotation for container "+self.inspect+" has leftover annotation markers: "+text
			return
		end
		self.annotated_content = text
		self.annotation_parsed = Time.now
		if !self.save
			warn "container failed to save after recalculating annotated content.  "+self.inspect+"\nErrors were: "+self.errors.inspect+
			"\nAnnotations were: "+self.annotations.inspect
		end
	end
	
	
	################################################################
	#																															 #
	#   Methods used in parsing the container                      #
	#																															 #
	################################################################
	
	def initialize_nlp(naive=false)
		# naive parsing breaks up tokens by spaces, normal parsing uses normal stanford rules to tokenize
		if naive
			return if @nlp_handle and @nlp_handle.get('naive')
			@nlp_handle = paragraph self.content
			@nlp_handle.segment
			@nlp_handle.apply(tokenize: :naive)
			@nlp_handle.set('naive', true)
		else
			return if @nlp_handle and !@nlp_handle.get('naive')
			@nlp_handle = paragraph self.content
			@nlp_handle.apply(:segment, :tokenize, :stem)
			@nlp_handle.set('naive', false)
		end
	end
	
	# finding definitions
	#####################
	
	def parse_definitions
		initialize_nlp
		calculate_definition_zone
		return if is_definition_zone? == false
		if is_definition_zone? or (self.parent and self.parent.is_definition_zone?)
			existing = Metadatum.where(category: "Definition", content_id: self.id)
			process_definitions
			deleted = Metadatum.where(category: "Definition", content_id: self.id) - existing
			deleted.each do |d|
				flag = d.flags.build(category: "Delete", comment: "A second parse through the container suggests this should be deleted.")
				flag.save
			end
			return
		end
	end

	def is_definition_zone?
		return definition_zone if definition_zone != nil
		self.definition_zone = calculate_definition_zone
		self.save
		return definition_zone
	end
	
	
	def definition_zone_scope
		match_scope    =    SCOPE_REGEX.match self.content.to_s
		match_purposes = PURPOSES_REGEX.match self.content.to_s
		if match_scope and STRUCTURAL_FEATURE_WORDS.include? match_scope[REGEX_STRUCTURAL_NAME].downcase
			return match_scope[REGEX_WHOLE_SCOPE]
		elsif match_purposes and STRUCTURAL_FEATURE_WORDS.include? match_purposes[REGEX_STRUCTURAL_NAME].downcase
			return match_purposes[REGEX_WHOLE_SCOPE]
			# if the heading or title of this section is dictionary or definit*
		else
			parent=self.parent
			if parent and parent.is_definition_zone?
				return parent.definition_zone_scope
			end
		end
		return false
	end
	
	
	def calculate_definition_zone
		return if definition_zone!=nil
		initialize_nlp
		if self.level <= SECTION
			self.definition_zone=definition_section_heading?
		elsif definition_zone_scope or definition_section_heading?
			self.definition_zone=true
		else
			# treat same as previous sibling
			previous = self.higher_item
			self.definition_zone = previous.definition_zone if previous
		end
		self.definition_zone = false if !self.definition_zone
		self.save
		return
	end	
	
	
	# finding anchors
	#####################
	
	def parse_anchors
		process_metadata_anchors
		process_internal_reference_anchors
	end
	
	
	################################################################
	#																															 #
	#   Class methods                                              #
	#																															 #
	################################################################
	
	def self.alias_to_level(word)
		log "converting "+word.inspect+" to a level" if DEBUG
		word=word.singularize unless word=="s"
		word_capitalized = word.clone
		word_capitalized[0] = word_capitalized[0].capitalize
		STRUCTURAL_ALIASES.each do | key, aliases|
			return key if (aliases & [word, word_capitalized]).size > 0
		end
		return nil
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

	#######################################################################
	#																															        #
	#   Private methods for parsing definitions                           #
	#																															        #
	#######################################################################
	
		
		def process_definitions
			
			@nlp_handle.apply(:parse)
			
			DEFINITION_PARSING_STRATEGIES.each do | word, params |
				phrases = highest_phrases_with_word_or_stem(@nlp_handle.phrases, word, params[:stem])
				if params[:filter_method]
					phrases.delete_if do |p|
						self.send(params[:filter_method], p)
					end
					if phrases.size > 0
						if DEBUG
							log "wrapping "+word+" phrases: " 
							phrases.each { |p| log p.inspect }
						end
						wrap_defined_terms(phrases)
						return
					end
				end
			end
		end
		
		def reject_mean_phrase?(p)
			means = p.words.find{ |w| w.to_s.downcase=="means"}
			if means 
				means.category
				return means.get(:category) == "noun"
			end
		end
		
		def reject_see_phrase?(p)
			para = p.ancestor_with_type(:zone)
			index = para.words.index { |w| w.to_s.downcase == "see" }
			if !index or index==0 or para.words[index-1].to_s.downcase == 'note'
				return true
			end
			return false
		end
			
		def translate_scope(scope_string)
			return nil if !scope_string
			# expects a string like 'any Act', 'this Act', 'this [structural term]'
			log "translating "+scope_string.inspect+" into a scope" if DEBUG
			scope_string.strip!.downcase!
			result = {}
			if scope_string == "any act"
				result[:universal_scope] = true
			else
				result[:universal_scope] = false
				p = scope_string.gsub(/[#{PUNCTUATION.join}]/, "").split(" ")
				if p[0] == "this"
					if !STRUCTURAL_FEATURE_WORDS.include?(p[1])
						info "trying to translate scope, found the word 'this', but don't know what type of structural term this is "+scope_string
					end
					if p[1] == "act"
						result[:scope] = self.act
					else
						parent = self.ancestors.find_by(level: Container.alias_to_level(p[1]))
						if !parent
							warn "trying to translate scope, couldn't find parent for "+self.inspect+".  Was looking for a level "+level.to_s
						end
						result[:scope] = parent
					end
				else
					result[:scope] = self.act.find_container(scope_string, self)
				end
			end
			return result
		end
		
		def definition_section_heading?
			initialize_nlp
			words = @nlp_handle.words
			if words.size > 3       # TODO LOW - make more sophisticated
				return false
			end
			return words.any?  { |w| w.stem.downcase == "definit" or w.to_s.downcase == "dictionary" }
		end
		
		def entity_includes_stem_or_word?(e, s, stem=true)
			if stem
				e.words.any? { |w| w.stem.downcase==s }
			else
				e.words.any?{ |w| w.to_s.downcase == s }
			end
		end
		
		def highest_phrases_with_word_or_stem(phrases, pattern, stem=true)
			return phrases.find_all do |p| 
				if !entity_includes_stem_or_word?(p, pattern, stem) or
					(p.parent.type == :phrase and entity_includes_stem_or_word?(p.parent, pattern, stem))
					next false
				end
				next true
			end
		end
		
		def create_definition(params)
			
			d = Metadatum.new(category: "Definition")
			d.anchor = [params[:anchor]]
			d.content=self
			if params[:universal_scope]
				d.universal_scope = true
			else
				d.scope = params[:scope]
			end
			if !d.save
				warn "definition failed to save "+d.inspect+"\nErrors were "+d.errors.inspect
				return nil
			end
			return d
		end

		def wrap_defined_terms(definition_phrases)
			definition_phrases.each do |p| 
				log "creating definition metadatum and annotation for "+p.to_s+" " if DEBUG
				index = p.position-1
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
				
				subject_words   = siblings[index].to_s
				scope           = translate_scope definition_zone_scope
				if !scope
					warn "translate_scope failed to get a definition_zone_scope from: "+definition_zone_scope
					next
				end
				universal_scope = scope[:universal_scope]
				scope_id        = scope[:scope] ? scope[:scope].id : nil
				scope_type      = scope[:scope] ? scope[:scope].class.to_s : nil
				if Metadatum.where(  content_id:   		self.id, 
														 anchor: 					[subject_words].to_yaml, 
														 category: 				"Definition", 
														 scope_id:      	scope_id,
														 scope_type:      scope_type,
														 universal_scope: universal_scope).count == 0
					create_definition anchor: 				 subject_words,
														scope:  				 scope[:scope],
														universal_scope: scope[:universal_scope]
				end
				position = self.content.index(/#{WORD_BOUNDARY_REPLACEMENT_FRONT+Regexp.quote(subject_words)+WORD_BOUNDARY_REPLACEMENT_BACK}/)
				if self.annotations.where(	anchor:   subject_words, 
																		category: "Defined_term", 
																		position: position ).count == 0
					create_annotation category: "Defined_term", anchor: subject_words, position: position
				end
			end
			self.definition_parsed = Time.now
			self.save
		end
	
	#######################################################################
	#																															        #
	#   Private methods for parsing internal and act references           #
	#																															        #
	#######################################################################
		
		
		def process_metadata_anchors(specific_metadata=nil)
			
			log "processing metadata for container "+self.id.to_s if DEBUG
			
			return false if self.level <= SECTION or self.special_paragraph == "Subheading"
			
			# find definitional anchors
			if specific_metadata
				relevant_metadata = specific_metadata
			else
				relevant_metadata = self.act.relevant_metadata
				# then add anything with scope == this item or its parents
				current = self
				while current != nil
					# TODO low: should be able to memoize this and make it more efficient
					current.scopes.each do |meta|
						relevant_metadata.push meta
					end
					current=current.parent
				end
			end
			
			puts "relevant_metadata is "+relevant_metadata.inspect
			
			relevant_metadata.each do |meta|
				log "processing metadatum "+meta.id.to_s if DEBUG
				next if meta.content == self
				meta.anchor.each do |anchor|
					log "processing anchor "+anchor if DEBUG
					# exclude any anchors that are a subset of an existing metadatum anchor
					regex = /#{WORD_BOUNDARY_REPLACEMENT_FRONT+Regexp.quote(anchor)+WORD_BOUNDARY_REPLACEMENT_BACK}/
					next if self.contents.any? { |content | content.anchor.any? { |a| regex.match a } }
					self.content.scan(regex) do |match|
						position = Regexp.last_match.offset(0).first
						# exclude any annotations that already exist
						next if self.annotations.where(anchor: anchor, metadatum_id: meta.id, position: position).size > 0
						log "trying to make a new annotation for container id "+self.id.to_s+" with anchor "+anchor+", "+
						"position of "+position.to_s+" and "+
						"metadatum of "+meta.inspect if DEBUG
						create_annotation anchor: anchor, position: position, metadatum: meta
					end
				end
			end
			self.recalculate_annotations if specific_metadata
		end
		
		
		def process_internal_reference_anchors
			return if self.level <= SECTION
			initialize_nlp(true)
			process_act_references
			process_container_references
			self.recalculate_annotations
		end
		
	
		def process_act_references
			
			return if @nlp_handle.children.size < 4 # has to be at least as long as 'the xxxx Act yyyy'
			
			tokens = @nlp_handle.children[2..-2]
			index  = 0
			
			tokens.each do |token|
				if token.to_s == 'Act' and tokens[index+1].type == :number
					last_word_index = index+1
				end
				
				first_word_index=nil
				current = index - 2 # start looking for the word 'the' - start 2 spots ahead of the word 'Act'
				
				while current > 0
					if tokens[current].to_s.downcase == 'the'
						first_word_index=current+1
						break
					end
					current-=1
				end
				next if !first_word_index
				act_words=tokens[first_word_index..last_word_index].join(" ")
				create_annotation anchor: act_words, position: self.content.index(/#{WORD_BOUNDARY_REPLACEMENT_FRONT+Regexp.quote(act_words)+WORD_BOUNDARY_REPLACEMENT_BACK}/), category: "Placeholder"
				index+=1
			end
		end
		
		def process_container_references
			
			@nlp_handle.children.each do |s| # children are the sentences/phrases - loop through them separately
				s.words.find_all{ |w| STRUCTURAL_FEATURE_WORDS[1..-1].include? w.to_s.downcase }.each do |structural_word|
					log "process_internal_reference_anchors looking at word "+structural_word.to_s if DEBUG
					if structural_word.to_s[-1] == 's' # ie plural
						tokens = structural_word.parent.children[structural_word.position+1..-1]
					else
						tokens = [structural_word.parent.children[structural_word.position+1]]
					end
					references=collect_references(tokens)
					next if (!references or references.size == 0)
					which_act = which_act?(references.last.parent.children[references.last.position+1..-1])
					log "which_act is "+which_act.inspect if DEBUG
					create_internal_reference(structural_word: structural_word.to_s, references: references, act: which_act)
				end
			end
		end
		
		def collect_references(tokens)
			so_far=[]
			while(add_to_references?(tokens.first, so_far))
				so_far.push tokens.shift
			end
			# if last token is a conjunction, delete it
			so_far.pop if LIST_CONJUNCTIONS.include? so_far.last.to_s
			log "collect_references result is " if DEBUG
			so_far.each { |s| log s.inspect } if DEBUG
			return so_far
		end
		
		def add_to_references?(token, so_far)
			return false if !token
			# if so_far > 0, then token could also be 'and', 'or' or 'to'
			return true  if so_far.size > 0 and ["and", "or", "to"].include? token.to_s
			# if the first character is an opening brace, and this follows a structural word, surely it's a reference to a container
			return true if token.to_s[0] == "(" and token.to_s.include? ")"
			reference = sentence token.to_s
			reference.tokenize
			# if the first character is a number, then surely also a container reference
			return true if reference.children.first.type == :number
			first=reference.children.first.to_s.downcase
			return true if ARABIC_REGEX.match first[0]
			# see if it's a roman numeral
			# to see if it's a stupid roman number like ivb, remove the last character, and see if what's left is 
			first = (PUNCTUATION.include? first[-1]) ? first[0..-1] : first
			roman_test = first[-1].between?('a', 'e') ? first[0..-1] : first
			return true if roman_test.length > 0 and ROMAN_REGEX.match roman_test
			# if it's a subdivision, the number might be a capitalized alphabetical
			return true if first.length == 1 and first.between?('A', 'Z')
		end
		
		def which_act?(tokens)
			log "finding which_act? for "+tokens.join(' ') if DEBUG
			return self.act if tokens.size < 4 # shortest it can be to be valid - 'of the x Act'
			return self.act if (tokens[0].to_s != "of" or tokens[1].to_s != "the")
			index = tokens.index { |x| /\bAct\b/.match x.to_s }
			return self.act if !index
			if tokens[index+1] 
				if tokens[index+1].type == :number
					return Act.find_act(tokens[2..index+1].join(' ')) # only need token index 2 onwards because index 0 is 'of' and 1 is 'the'
				elsif (PUNCTUATION.include? tokens[index+1].to_s[-1]) and ARABIC_REGEX.match tokens[index+1].to_s[0..-2]
					return Act.find_act(tokens[2..index+1].join(' ')[0..-2])
				end
			end
			return Act.find_act(tokens[2..index].join(' '))
		end
			
		
		def find_or_create_internal_reference(params)
			
			# API:
			# container:       container
			# anchor:          string
			# can't just use find_or_create_by because it doesn't deal with with serialized fields
			# TODO LOW - consider making the anchors a separate object so we can avoid serialization
			
			log "trying to find internal reference for "+params[:anchor].inspect+" which points to "+params[:container].inspect if DEBUG
			
			result = Metadatum.find_by           category: 		 "Internal_reference", 
																					 content_id:   params[:container].id, 
																					 content_type: "Container",
																					 scope_id:     self.id,
																					 scope_type:   "Container",
																					 anchor:       [params[:anchor]].to_yaml
			
			if !result
				result = Metadatum.new
				result.category="Internal_reference"
				result.content = params[:container]
				result.scope = self
				result.anchor = [params[:anchor]]
				if !result.save 
					warn "tried to save a new internal reference but it errored:\n"+result.inspect+
					"\nerrors: "+result.errors.inspect
					return nil
				end
			end
			return result
		end
		
		def create_internal_reference(params)
			
			# API: 
			# structural_word: string    - like 'section', 'subsection' etc
			# references:      [tokens]  
			# act:             act
			
			return if !params[:act] or !params[:references] or !params[:structural_word] or params[:references].length == 0
			
			if DEBUG
				log "trying to create internal reference.\nstructural level is: "+level.to_s+
				"\nand act is "+params[:act].id.to_s+
				"\nand references are: "
				params[:references].each { |r| log r.inspect }
			end
			
			params[:references].each do |r| 
				first = params[:references].first==r
				r=r.to_s
				next if LIST_CONJUNCTIONS.include? r
				r=r[0..-2] if PUNCTUATION.include? r[-1]
				
				anchor = first ? params[:structural_word]+" "+r.to_s : r.to_s
				
				container = params[:act].find_container(params[:structural_word]+" "+r.to_s, self)
				
				if !container
					warn "could not find a container for "+anchor+".  Self has id "+self.id.to_s
					next
				end
				
				reference = find_or_create_internal_reference container: container, anchor: anchor
				
				if !reference
					warn "failed to find internal reference."
					warn "was trying to create internal reference for "+anchor.inspect+
					"\nand trying to find a reference for container "+container.inspect
					next
				end
				
				create_annotation anchor:    reference.anchor.first, 
																		 position:  self.content.index(/#{WORD_BOUNDARY_REPLACEMENT_FRONT+Regexp.quote(reference.anchor.first)+WORD_BOUNDARY_REPLACEMENT_BACK}/), 
																		 metadatum: reference
			end
		end
			
		
		def self.number_to_level(num)
			return nil if !num or num.length == 0
			if num[0].between?('0', '9')
				return SUBSECTION
			elsif num[0].between?('A', 'Z')
				return SUBSUBPARAGRAPH
			elsif num[0].between?('a', 'z')
				return PARAGRAPH
				# potentially wrong as i, v and x could be romans
			else
				raise "don't know what this num is "+num.inspect
			end
		end
		
		def create_annotation(params)
			log "Create_annotation called with params "+params.inspect
			metadatum_id = params[:metadatum] ? params[:metadatum].id : nil
			if self.annotations.where(position:      params[:position],
				anchor:        params[:anchor],
				metadatum_id:  metadatum_id        ).size > 0 
				return
			end
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
				warn "annotation failed to save - "+a.inspect+"\nErrors were: "+a.errors.inspect+"\nanchor was "+a.anchor
				# flag the container for review
				flag = self.flags.create(category: "Review", comment: "anchor based on this failed "+a.inspect+"\nMessages were "+a.errors.inspect)
				flag.save
			end
		end
	
		
	#######################################################################
	#																															        #
	#   Private methods for supporting the comparison rules               #
	#																															        #
	#######################################################################
		
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
			
			return compare_arabic_numbers(to_roman(first), to_roman(second))
		end
		
		def self.compare_alphabetical_numbers(first, second)
			
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
			
			# if we're here, we've already determined that these two elements have the same ancestors, and one of them
			# has no children.  That one also has no position, which means it hasn't been saved into the DB yet
			
			# so this is purely a comparison of their 'numbers', and if they don't have numbers, then their paragraph texts
			
			if first.level != second.level and (first.number or second.number)
				# ie, if the two containers are different levels, and they're not both paragraphs
				# assume the one that's a higher structural element is higher up in the Act
				return first.level <=> second.level
			end
			
			is_roman = (first.level == SUBPARAGRAPH) or (first.level == PART and (['i', 'v', 'x'].include? first.number[0].downcase))
			
			if is_roman
				result= compare_romans(first.number, second.number)
			elsif [SECTION, SUBSECTION, CHAPTER, DIVISION, PART].include? first.level
				result= compare_arabic_numbers(first.number, second.number)
			elsif [PARAGRAPH, SUBSUBPARAGRAPH, SUBDIVISION].include? first.level
				result= compare_alphabetical_numbers(first.number, second.number)
			else
				result= compare_paragraphs(first, second)
			end
			return result 
		end

		
		def self.compare_arabic_numbers(first, second)
			
			if ARABIC_REGEX.match first.to_s+second.to_s
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
				return first <=> second
			end
			
			is_ITAA97 = false
			match = ITAA97_REMAINDER_REGEX.match first_remainder
			if match
				first_remainder = match[1]
				is_ITAA97 = true
			end
			match = ITAA97_REMAINDER_REGEX.match second_remainder
			if match
				second_remainder = match[1] if match
				is_ITAA97 = true
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

	
	#######################################################################
	#																															        #
	#   Other                                                             #
	#																															        #
	#######################################################################
		
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
	
		
end
