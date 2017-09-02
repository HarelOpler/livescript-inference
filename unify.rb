require "pp"

class Equation
	attr_accessor :left, :right
	def initialize(left,right)
		@left, @right = left,right
	end
end

class Constant #string, int, ect...?
	attr_accessor :name
	def initialize(name)
		@name = name
	end

	def compare(other)
		other.compareConst(self)
	end

	def compareConst(other)
		if @name == other.name
			UnifyResult.new([],{})
		else
			UnifyResult.new()
		end
	end

	def compareCompound(other)
		UnifyResult.new()
	end

	def compareVar(other)
		UnifyResult.new([], {other => self}) #based on names for now
	end
end

class TypeVar
	attr_accessor :name
	def initialize(name)
		@name = name
	end

	def compare(other)
		other.compareVar(self)
	end

	def compareConst(other)
		UnifyResult.new([], {self => other})
	end

	def compareCompound(other)
		if other.vars.include?(@name)
			UnifyResult.new().error!
		else
			UnifyResult.new([], {self => other})
		end
	end

end


class Compound
	attr_accessor :head, :tail, :vars
	def initialize(head,tail,vars) #for now lets get the vars which in tail
		@head, @tail, @vars = head,tail,vars
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
		if @head != other.head or arity() != other.arity
			return UnifyResult.new().error!
		end
		zipped = @tail.zip(other.tail)
		UnifyResult.new(zipped.map { |pair|  Equation.new(*pair) }, {})
	end

	def compareVar(other)
		if @vars.include?(other.name)
			UnifyResult.new().error!
		else
			UnifyResult.new([], {other => self})
		end
	end
end

class UnifyResult
	attr_accessor :equations, :substitutions
	def initialize(equations=[], substitutions={})
		@equations = equations
		@substitutions = substitutions
		@error = false
	end
	def error!()
		@error = true
		self
	end

	def error?
		@error
	end
end

class Unify
	def initialize(equations)
		@equations = equations
		@substitutions = {}
	end

	def unifiy
		while !@equations.empty?
			eq = @equations.pop
			pp eq
			pp "---"
			result = eq.left.compare(eq.right)
			if result.error?
				return "Can't unifiy"
			end
			new_eq, subs = result.equations, result.substitutions
			@equations += new_eq
			@substitutions.merge! subs
		end
		@substitutions
	end

end

var1 = TypeVar.new("a")
var2 = TypeVar.new("b")
var3 = TypeVar.new("g")
var4 = TypeVar.new("h")
var5 = TypeVar.new("h")
var6 = TypeVar.new("d")

const1 = Constant.new("c")
const2 = Constant.new("e")


comp1 = Compound.new("g",[var1],["g","a"])
comp2 = Compound.new("b",[var3],["b","g"])
comp3 = Compound.new("f",[comp1,comp2],["b","g","a"])

comp4 = Compound.new("h",[const1],["h"])
comp5 = Compound.new("d",[const2],["d"])
comp6 = Compound.new("f",[comp4,comp5],["h","d"])

eqs = [Equation.new(comp3,comp6)]
pp Unify.new(eqs).unifiy
