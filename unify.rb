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
end
require './vars.rb'

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
		@subtype_equations = []
		vars += equations.flat_map { |e| [e.left, e.right] }
		vars.push(EmptyUnifier.new) # for initializing 
		@union = UnionFind::UnionFind.new(Set.new(vars))
		@vars_name = {}
		CONSTANTS.each {|c|
			@vars_name[c] = Constant.new(c)
			@union.add(@vars_name[c])
		}
		@error = false
	end

	def unify
		# @equations.sort! {|x,y| x.length <=> y.length}
		pp "---unifying...---"
		if @error
			raise "Can't unifiy"
		end
		print_equations()

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
				pp "#{name.name} is head of #{val.name}"
					head = @union.union(name,val)
					tail = head == name ? val : name
					update_actual_types(head,tail)
				end	
			}
		end

		@union
	end

	def simplify_constraints

	end

	def print_unification
		pp @union
	end

	def print_equations
		@equations.each { |eq|
			pp "#{eq.left.name} == #{eq.right.name}"
		}
	end

	def print_subtypes_equations
		@subtype_equations.each { |st|
			l = @union.parent(st.left).actual_type
			r = @union.parent(st.right).actual_type
			pp "#{l.name} <: #{r.name}"
		}
	end

	def add_equation(eq)
		@equations << eq
		@union.add(eq.left)
		@union.add(eq.right)
		eq
	end

	def add_subtype(st)
		@subtype_equations << st
		# add to graph
		st
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

	def set_error
		@error = true
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