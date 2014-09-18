####################################################################
#   DEFINITIONS AND CROSS REFERENCES                               #
####################################################################

SCOPE_REGEX =    /[Ii]n( this| any)? (\w+)( [\diI]+\w*(\(\w+\))?)?[,:-]/
PURPOSES_REGEX = /[Ff]or the purposes of (\w+)( [\diI]+\w*(\(\w+\))?)?[,:-]/

DEFINITION_WRAPPERS = ["<span class=defined_term>", "</span>"]
REFERENCE_WRAPPERS  = ["<span class=reference>",    "</span>"]

class Container < ActiveRecord::Base
		
	belongs_to :act
	acts_as_list scope: :act
	belongs_to :parent,   class_name: "Container"
	has_many   :children, class_name: "Container", foreign_key: "parent_id"
	has_many :comments, dependent: :destroy
	
	
	validates_presence_of :act
	validates :act_id, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :number, presence: true, unless: lambda { self.depth == TEXT or self.depth == PARA_LIST_HEAD}
	validates :depth, presence: true, numericality: {only_integer: true, greater_than: 0}
	validates :regulations, numericality: {only_integer: true, greater_than: 0}, :allow_blank => true  # TODO MEDIUM: this is not right - needs to be a formal relation
	
	default_scope -> {order('position ASC')} 
	
	@is_definition_zone = nil
	
	if Rails.env.development?
		attr_accessor :nlp_handle, :mp, :ip, :sp
	end
		
	def previous_sibling(previous_containers)
		parent = self.new_record? ? self.parent_id : self.parent
		if !parent
			return nil
		end
		siblings=[]
		if self.new_record? and previous_containers.size>0
			previous_containers.each do |k, v|
				if v.parent_id == parent
					siblings.push v
				end
			end
		else
			siblings = parent.children
		end
		index = siblings.index self
		if siblings.size <= 1 or index==0
			return nil
		end
		return siblings[index-1]
	end
	
	def type
		return STRUCTURAL_ALIASES[self.depth][0].downcase
	end
	
	def names
		if self.depth >= PARA_LIST_HEAD
			return nil
		end
		result = []
		num = self.depth < SECTION ? self.number : subsection_citation
		num_start = /\d/.match(num[0]) ? true : false
		
		STRUCTURAL_ALIASES[self.depth].each do |name|
			result.push name+" "+num
			if num_start
				result.push name+num
			end
		end
		result.push num
		return result
	end
	
	def subsection_citation(current=self)
		if current.depth >= PARA_LIST_HEAD or current.depth < SECTION
			return nil
		end
		result = ""
		while current.depth > SECTION
			if current.number
				result = "("+current.number+")" + result
			end
			current=current.parent
		end
		result = current.number+result
		return result
	end
	
	def citation
		
		if self.depth == CHAPTER
			return self.type+" "+self.number
		elsif self.depth < SECTION
			current=self
			result=[]
			while current and current.depth >= PART
				result.push self.type+" "+self.number
				current = current.parent
			end
			return result.join(" ,")
		else 
			start  = ""
			result = ""
			if self.depth >= PARA_LIST_HEAD
				start = "text in "
				current = self.parent
				while current.depth >= PARA_LIST_HEAD
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

	def definition_section_heading?
		if !self.new_record? and !@nlp_handle
			parse
		end
		words = @nlp_handle.words
		if words.size > 3       # TODO LOW - make more sophisticated
			return false
		end
		return words.any?  { |w| w.stem.downcase == "definit" or w.to_s.downcase == "dictionary" }
	end
	
	def is_definition_zone?(previous_containers)
		if @is_definition_zone != nil
			puts "using memoized value"
			return @is_definition_zone 
		end
		if self.depth <= SECTION
			return definition_section_heading?
		end
		match = SCOPE_REGEX.match section.title.to_s
		match_purposes = PURPOSES_REGEX.match section.title.to_s
		if match and STRUCTURAL_FEATURE_WORDS.include? match[2].downcase
			return @is_definition_zone = true
		elsif match_purposes and STRUCTURAL_FEATURE_WORDS.include? match_purposes[1].downcase
			return @is_definition_zone = true
			# if the heading or title of this section is dictionary or definit*
		elsif definition_section_heading?
			return @is_definition_zone = true
			# if more elegant way of detecting subheadings found, this needs changing too
			# if it's a subsection or lower, and the previous subheading is dictionary or definit*
		end
		parent = self.new_record? ? previous_containers[self.parent_id] : self.parent
		if parent and parent.is_definition_zone?(previous_containers)
			return @is_definition_zone = true
		end
		# treat same as previous sibling
		previous = previous_sibling(previous_containers)
		if previous
			return @is_definition_zone = previous.is_definition_zone?(previous_containers)
		end
		return @is_definition_zone = false
	end
	
	def initialize_nlp
		@nlp_handle = paragraph self.content
		@nlp_handle.apply(:segment, :tokenize, :stem)
	end
		
	def parse(previous_containers = {})
		start_time=Time.now
		initialize_nlp
		if is_definition_zone?(previous_containers)
			process_definitions
		end
		puts "parsing definitions took "+(Time.now-start_time).to_s if DEBUG
		start_time = Time.now
		process_references
		puts "parsing references took "+(Time.now-start_time).to_s if DEBUG
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
	
	def wrap_words_with_tags(words, open_tag, close_tag)
		words.first.value = open_tag  + words.first.value
		words.last.value  = words.last.value + close_tag
	end
	
	def wrap_defined_terms(definition_phrases)
		definition_phrases.each do |p| 
			puts "wrapping "+p.to_s+" " if DEBUG
			index = p.position-1
			puts "index is "+index.to_s
			if index==-1
				puts "cannot wrap definition phrase as it is the first phrase" if DEBUG
				return
			end
			siblings=p.parent.children
			while index > 0 and siblings[index].type != :phrase
				index-=1
			end
			puts "siblings[index] is "+siblings[index].to_s+" and index is "+index.to_s+" and inspect is "+siblings[index].inspect+" and its children are "+siblings[index].children.inspect if DEBUG
			subject_words = siblings[index].words
			if subject_words.size == 0
				subject_words=siblings[index].children
			end
			wrap_words_with_tags(subject_words, DEFINITION_WRAPPERS[0], DEFINITION_WRAPPERS[1])
		end
	end
	
	def process_definitions
		
		@nlp_handle.apply(:parse)

		puts "phrases found" if DEBUG
		
		@mp = highest_phrases_with_word_or_stem(@nlp_handle.phrases, "mean", true)
		
		# exclude where 'means' is used as a noun
		@mp.delete_if do |p|
			means = p.words.find{ |w| w.to_s.downcase=="means"}
			if means 
				means.category
				next means.get(:category) == "noun"
			end
		end
		puts "wrapping @mp phrases "+@mp.inspect+" " if DEBUG
		wrap_defined_terms(@mp)
		
		if @mp.size == 0
			@ip = highest_phrases_with_word_or_stem(@nlp_handle.phrases, "includ", true)
			if @ip and @mp 
				@ip -= @mp
			end
			puts "wrapping @ip phrases "+@ip.inspect+" " if DEBUG
			wrap_defined_terms(@ip)
			
			if @ip.size == 0
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
				puts "wrapping @sp phrases "+@sp.inspect+" " if DEBUG
				wrap_defined_terms(@sp)
			end
		end

		self.content = @nlp_handle.to_s

	end
	
	def process_references
		
		# find all Act names so we can italicise them
		
		if entity_includes_stem_or_word?(@nlp_handle, "Act", false, false)
			indices = []
			index = 0
			tokens = @nlp_handle.tokens
			
			tokens.each do |w|
				if w.type == :word and w.value == "Act"
					indices.push index
				end
				index+=1
			end
			
			indices.each do |i|
				
				next if !tokens[i+1] or tokens[i+1].type!= :number
				last_word = tokens[i+1]
				first_word = nil
				current=i-2
				while current > 0 
					if tokens[current].value.downcase == 'the'
						first_word = tokens[current+1]
						break
					end
					current-=1
				end
				next if !first_word
				wrap_words_with_tags([first_word, last_word], REFERENCE_WRAPPERS[0], REFERENCE_WRAPPERS[1])
				self.content = @nlp_handle.to_s
			end
		end
		# TODO MEDIUM: find all 'acts', 'Chapters', 'Parts', etc and metadata them
	end
	
=begin
	def strip_number
		if self.depth >= SUBSECTION and self.depth <= SUBSUBPARAGRAPH
			close_brace_index = self.content.index(')')
			return self.content[close_brace_index+1..-1].strip
		else
			return self.content
		end
	end
=end
	
end