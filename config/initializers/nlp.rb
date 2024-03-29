# encoding UTF-8

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
			current.set :level,  (c.get :level)
			current.set :number, (c.get :number)
			current.set :strip_number, (c.get :strip_number)
			c.set :level, nil
			c.set :number, nil
			c.set :strip_number, nil
		end
		current << c
	end
end

Treat::Workers::Processors::Tokenizers.add(:naive) do |sentence, options={}| 
  sentence.to_s.split(' ').each do |token|
		match = /\A(\d+.*)(-)(\D.+)/.match token  # ie something like Part 3-see.
		match = /\A(.+)\)(-)(.+)/.match token if !match
		if match
			sentence << Treat::Entities::Token.from_string(match[1])
			sentence << Treat::Entities::Token.from_string(match[2])
			sentence << Treat::Entities::Token.from_string(match[3])
		else
			sentence << Treat::Entities::Token.from_string(token)
		end
  end
end

Treat::Workers::Processors::Tokenizers.add(:lgd2) do |entity, options={}| 
	entity.check_hasnt_children
	if entity.has_children?
		raise Treat::Exception,
		"Cannot tokenize an #{entity.class} " +
		"that already has children."
	end
	chunks = Act.tokenizer_split(entity.to_s, options)
	chunks.each do |chunk|
		next if chunk =~ /([[:space:]]+)/
		entity << Treat::Entities::Token.from_string(chunk)
	end
end