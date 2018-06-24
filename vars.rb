
class SubType < Equation
end

class TemplateVar
	attr_accessor :name, :actual_type
	alias_method :eql?, :==

	def hash
    	state.hash
  	end
	def state
		@name
	end
	def eql?(o)
		o.class == self.class && o.state == state
	end

end

class Constant < TemplateVar #string, int, ect...?
	
	def initialize(name)
		@name = name
		@actual_type = self
	end

	def compare(other)
		other.compareConst(self)
	end

	def compareConst(other)
		if @name == other.name
			UnifyResult.new([],{})
		else
			UnifyResult.new().error!
		end
	end

	def compareCompound(other)
		UnifyResult.new().error!
	end

	def compareVar(other)
		UnifyResult.new([], {self => other}) #based on names for now
	end



	def sub_vars(subs)
		self
	end

	def vars
		[@name]
	end
end

class TypeVar < TemplateVar
	def initialize(name)
		@name = name
		@actual_type = self
	end

	def compare(other)
		other.compareVar(self)
	end

	def compareConst(other)
		UnifyResult.new([], {other => self})
	end

	def vars
		[@name]
	end

	def compareCompound(other)
		if other.vars.include?(@name)
			UnifyResult.new().error!
		else
			UnifyResult.new([], {other => self})
		end
	end

	def compareVar(other)
		UnifyResult.new([], {self => other})
	end

	def sub_vars(subs)
		subs[self] || self
	end
end

class Compound
	attr_accessor :head, :tail, :vars, :actual_type, :elements_type
	def initialize(head,tail,vars) #for now lets get the vars which in tail
		@head, @tail, @vars = head,tail,vars
		@actual_type = self
	end

	def arity
		tail.size
	end

	def compare(other)
		other.compareCompound(self)
	end

	def compareConst(other)
		return UnifyResult.new().error!
	end

	def compareCompound(other)
		if arity() != other.arity
			return UnifyResult.new().error!
		end
		result = @head.compare(other.head)
		if result.error?
			return result
		end

		zipped = @tail.zip(other.tail)
		UnifyResult.new(zipped.map { |pair|  Equation.new(*pair) } + result.equations, result.substitutions)
	end

	def compareVar(other)
		if @vars.include?(other.name)
			UnifyResult.new().error!
		else
			UnifyResult.new([], {self => other})
		end
	end

	def sub_vars(subs)
		to_sub = vars & subs.keys.map { |e| e.name }
		return self if to_sub.empty?
		@head ||= subs[@head]
		@tail.map! { |var|
			var.sub_vars
		}
		self

	end

	def name
		if @head.name == "Array"
			"[" + @tail.map { |e| e.name }.join(",") + "]"
		else
			head = @head.name
			if @head.class == Compound
				head = "(#{head})"
			end
			head + "->" + @tail.map { |e| 
				e.name
			}.join(",")
		end
	end

		def self.create_function_type(scope)
		alpha = VarUtils.gen_type()
		beta = VarUtils.gen_type()
		ftype = Compound.new(alpha, [beta], [beta])
		scope.add_var_unifier(alpha,beta,ftype)

		[alpha,beta,ftype]
	end
end


class VarUtils
	@@counter = 0
	def self.gen_type()
		@@counter+=1
		t = TypeVar.new("T-" + @@counter.to_s,)
	end
end