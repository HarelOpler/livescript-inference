require "pp"
require "set"
require "union_find"

CONSTANTS = ["int","string","bool","float","null", "Array", "unit"]


class Equation
	attr_accessor :left, :right
	def initialize(left,right)
		@left, @right = left,right
	end
	
	def self.create_compound(ts,unifier)
		if ts.size == 1
			if CONSTANTS.include?(ts.first)
				return unifier.add_var(Constant.new(ts.first))
			elsif ts.first[0] == "["
				inner_type = ts.first[1..-2] # extract t from [t]
				inner_type = create_compound([inner_type],unifier)
				return unifier.add_var(Compound.new(Constant.new("Array"),[inner_type],[inner_type]))
			else
				return unifier.add_var(TypeVar.new(ts.first))
			end
		end
		head = create_compound([ts[0]],unifier)
		tails = create_compound(ts[1..-1],unifier)
		unifier.add_var(Compound.new(head,[tails],tails.vars.insert(0,head.name)))
	end

	def self.from_string(s,unifier)
		types = s.split("->")
		# reminder: deal with function type parameters
		self.create_compound(types,unifier)
	end

	def length
		@left.length + @right.length
	end
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
	attr_accessor :head, :tail, :vars, :actual_type
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
			@head.name + "->" + @tail.map { |e| e.name }.join(",")
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

class UnionFind::UnionFind
	def parent(v)
		@parent[v].nil? ? v : @parent[v]
	end
	def parents
		@parent
	end
end

class EmptyUnifier

end

class Unify
	def initialize(equations, vars)
		@equations = equations
		vars += equations.flat_map { |e| [e.left, e.right] }
		vars.push(EmptyUnifier.new) # for initializing 
		@union = UnionFind::UnionFind.new(Set.new(vars))
		@vars_name = {}
		CONSTANTS.each {|c|
			@vars_name[c] = Constant.new(c)
			@union.add(@vars_name[c])
		}
	end

	def unify
		# @equations.sort! {|x,y| x.length <=> y.length}
		while !@equations.empty?
			eq = @equations.pop
			l = @union.parent(eq.left).actual_type
			r = @union.parent(eq.right).actual_type
			result = l.compare(r)
			if result.error?
				raise "Can't unifiy"
			end
			new_eq, subs = result.equations, result.substitutions
			# pp subs
			@equations += new_eq
			new_eq.each { |e| @union.add(e) }
			subs.each_pair { |name, val|
				unless name.name == val.name
				# pp "#{name.name} is head of #{val.name}"
					head = @union.union(name,val)
					tail = head == name ? val : name
					update_actual_types(head,tail)
				end	


			}
		end

		@union
	end

	def print_unification
		pp @union
	end

	def add_equation(eq)
		@equations << eq
		@union.add(eq.left)
		@union.add(eq.right)
		eq
	end

	def add_var(v)
		@vars_name[v.name] = v
		@union.add(v)
		v
	end
	def add_const(c)
		@vars_name[c.name] = c
		c
	end
	def parent(vn)
		p = @union.parent(@vars_name[vn])
		if p.class == Compound
			vars = []
			return Compound.new(parent(p.head.name),
								p.tail.map { |e| 
									par = parent(e.name)
									vars << par
									par
									 }, 
								vars + [parent(p.head.name)]) 
		end
		return p
	end

	def update_actual_types(head,tail)
			if tail.class == TypeVar
					head.actual_type = head.actual_type						
				elsif tail.class == Constant
					head.actual_type = tail.actual_type
				else #Compound
					if head.actual_type.class == TypeVar
						head.actual_type = tail.actual_type
					else head.actual_type.name != tail.actual_type.name
						@equations << Equation.new(head.actual_type,tail.actual_type)
					end
				end
	end
end

# x = TypeVar.new("x")
# y = TypeVar.new("y")
# z = TypeVar.new("z")
# w = TypeVar.new("w")
# u = TypeVar.new("u")
# v = TypeVar.new("v")

# a = Constant.new("a")
# b = Constant.new("b")
# c = Constant.new("c")
# f = Constant.new("f")
# g = Constant.new("g")
# list = Constant.new("list")


# yx = Compound.new(y,[x],["y","x"])
# xy = Compound.new(x,[y],["x", "y"])

# fy = Compound.new(f,[y],["y"])

# eqs = [Equation.new(xy,z), Equation.new(yx,w), Equation.new(z,w)]
# a = Unify.new(eqs,[x,y,z,w]).unify
# pp a 
# b = Unify.new([Equation.new(fy,x)],[y,x]).unifiy
# pp b.parent(y)
# pp Equation.from_string("a->b->c")