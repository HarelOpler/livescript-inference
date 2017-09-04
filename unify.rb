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
			UnifyResult.new().error!
		end
	end

	def compareCompound(other)
		UnifyResult.new().error!
	end

	def compareVar(other)
		UnifyResult.new([], {other => self}) #based on names for now
	end

	def sub_vars(subs)
		self
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

	def compareVar(other)
		UnifyResult.new([], {self => other})
	end

	def sub_vars(subs)
		subs[self] || self
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
			UnifyResult.new([], {other => self})
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
			result = eq.left.compare(eq.right)
			if result.error?
				return "Can't unifiy"
			end
			new_eq, subs = result.equations, result.substitutions
			@equations += new_eq

			@substitutions.merge! subs
			@equations.map! { |eq|
				Equation.new(eq.left.sub_vars(@substitutions),eq.right.sub_vars(@substitutions))
			}
			
		end
		@substitutions
	end

	def print_subs
		@substitutions.each_pair { |name, val|
			pp name
			print "\t->\t"
			pp val
		}
	end
end

x = TypeVar.new("x")
y = TypeVar.new("y")
z = TypeVar.new("z")
w = TypeVar.new("w")
u = TypeVar.new("u")
v = TypeVar.new("v")

a = Constant.new("a")
b = Constant.new("b")
c = Constant.new("c")
f = Constant.new("f")
g = Constant.new("g")
list = Constant.new("list")


yx = Compound.new(y,[x],["y","x"])
xz = Compound.new(x,[z],["x", "z"])

eqs = [Equation.new(xz,yx)]
pp Unify.new(eqs).unifiy
