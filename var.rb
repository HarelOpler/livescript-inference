class Variable
	attr_accessor :name, :is_this, :type, :is_paran
	def initialize(name)
		@name, @is_this, @type = name, false, Type.new
		@is_paran = false
	end

	def set_type(name)
		@type = Type.new(name)
	end

	def in_parens(name)
		@type.add_parens(name)
	end
	## Equality definitions
	alias_method :eql?, :==

	def hash
    	state.hash
  	end
	def state
		[@name, @is_this]
	end
	def ==(o)
    	o.class == self.class && o.state == state
  	end
end

class Type
	@@counter = 0
	attr_accessor :name
	def initialize(type="")
		if type.empty?
			@name = "T-" + @@counter.to_s
			@@counter += 1
		else
			@name = sub_blanks(type)
			@@counter += 1 if @name != type
		end
		@compound = false
	end

	def add_parens(type)
		if @compound
			@name.sub!("]", "[" + type + "]]")
			@name = sub_blanks(@name)
			return
		end
		@name += "[" + sub_blanks(type) + "]"
		@compound = true
	end

	def sub_blanks(s)
		s.gsub("_","T-"+@@counter.to_s)
	end

	def self.function(params, return_type)
		name = params.map { |p| p.type.name }.join("->") + "->" + return_type.type.name
		Type.new(name)
	end
end