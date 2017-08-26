class Variable
	attr_accessor :name, :is_this
	def initialize(name)
		@name, @is_this = name, false
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