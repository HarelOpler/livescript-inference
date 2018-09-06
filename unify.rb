require "pp"
require "set"
require "union_find"
require 'rgl/adjacency'
require 'rgl/dot'
require 'rgl/condensation'

CONSTANTS = ["int","string","bool","float","null", "Array", "unit","Any"]


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
		@constants = CONSTANTS
		CONSTANTS.each {|c|
			@vars_name[c] = Constant.new(c)
			@union.add(@vars_name[c])
		}
		@error = false
		@coercion = Coercion.new
		@properties = Properties.new
		@property_tree = Properties.new
		@type_source = {}
		init_coercions()
		
	end

	#ALGO METHODS
	def unify
		# @equations.sort! {|x,y| x.length <=> y.length}
		# pp "---unifying...---"
		if @error
			raise "Can't unifiy"
		end
		# print_equations
		# print_subtypes_equations

		while !@equations.empty?
			eq = @equations.pop
			# pp eq.left
			l = get_type_from_var(eq.left)
			# l = @union.parent(eq.left).actual_type
			r = get_type_from_var(eq.right)
			# r = @union.parent(eq.right).actual_type
			result = l.compare(r)
			if result.error?
				pp eq
				raise "Can't unifiy #{l.name} == #{r.name}"
			end
			new_eq, subs = result.equations, result.substitutions
			# pp subs
			@equations += new_eq
			new_eq.each { |e| @union.add(e) }
			subs.each_pair { |name, val|
				# pp "#{name.name} is head of #{val.name}"
				unless name.name == val.name
					head = @union.union(name,val)
					unless head.nil?
						tail = head == name ? val : name
						update_actual_types(head,tail)
					end
				end	
			}
		end
		@equations.map!() {|eq| 
			Equation.new(parent(eq.left.name).actual_type,parent(eq.right.name).actual_type)
		}
		@subtype_equations.map!() {|eq| 
			SubType.new(parent(eq.left.name).actual_type,parent(eq.right.name).actual_type)
		}
		@union
	end

	def simplify
		simplified = true
		final_subtypes = []
		while simplified && !@subtype_equations.empty?
			simplified = true
			# left <: right
			subeq = @subtype_equations.pop
			# left = subeq.left.actual_type
			# right = subeq.right.actual_type
			left = get_type_from_var(subeq.left)
			right = get_type_from_var(subeq.right)

			# Decompose
			if left.class == Compound && right.class == Compound
				# pp "Decomposing #{left.name} and #{right.name}"
				@subtype_equations.push(SubType.new(right.head, left.head))
				# @subtype_equations.push(SubType.new(left.head, right.head))
				@subtype_equations.push(SubType.new(left.tail.first, right.tail.first))
			elsif left.class == Constant && right.class == Constant
				# pp "Eliminating constants #{left.name} and #{right.name}"
				if !@coercion.can_coerce?(left,right)
					raise "Can't unifiy - coercion fail #{left.name} <: #{right.name}" 
				end
				#make sure they indeed subtype of one another
			# elsif left.kind_of?(TemplateVar) && right.kind_of?(TemplateVar)
				# pp "Unifying templates vars #{left.name} and #{right.name}"
				# add_equation(Equation.new(left,right))
			elsif left.class == TypeVar && right.class == Compound
				# Add to unify that left is now C(...)
				alpha = VarUtils.gen_type()
				beta = VarUtils.gen_type()
				if right.head.name == "Array"
					ftype = Compound.new(Constant.new("Array"),[beta],[alpha])
				else
					ftype = Compound.new(alpha,[beta],[alpha,beta])
				end
				add_var(alpha)
				add_var(beta)
				add_var(ftype)
				@subtype_equations.push(SubType.new(ftype, right))
				add_equation(Equation.new(left,ftype))
				# pp "Structure of #{left.name} must be as #{right.name} (now is #{ftype.name})"
			elsif left.class == Compound && right.class == TypeVar
				alpha = VarUtils.gen_type()
				beta = VarUtils.gen_type()
				if left.head.name == "Array"
					ftype = Compound.new(Constant.new("Array"),[beta],[alpha])
				else
					ftype = Compound.new(alpha,[beta],[alpha,beta])
				end
				add_var(alpha)
				add_var(beta)
				add_var(ftype)
				@subtype_equations.push(SubType.new(left, ftype))
				add_equation(Equation.new(ftype,right))
				# pp "Structure of #{right.name} must be as #{left.name} (now is #{ftype.name})"
			else
				# pp "No rule to apply. #{left.name} #{right.name}"
				final_subtypes << subeq
				if @subtype_equations.empty?
					simplified = false
				end
			end

		end
		@subtype_equations = final_subtypes
		unify
		are_equations_legal?()
	end

	def are_equations_legal?()
		@subtype_equations.each { |seq|
			l = seq.left
			r = seq.right
			if (l.class == TypeVar && r.class == Compound) ||
				(l.class == Constant && r.class != TypeVar)
				raise "Can't Unify (#{l.name + '<:' +  r.name})"
			end
			# pp "Passed: #{seq.left.name} <: #{seq.right.name}"
		}
	end
	def infer
		# print_equations()

		unify
		to_graph()#.write_to_graphic_file('jpg','graphs/before_simplify')

		simplify()
		@dg = to_graph()
		@dg.write_to_graphic_file('jpg', 'graphs/dg')
		can_cycle_elim?(@dg)
		cdg = @dg.condensation_graph
		hset = {}
		cdg.vertices.map { |v| type_condensation(v,hset) }
		tdg = RGL::DirectedAdjacencyGraph[]
		hset.values.each {|t|
			tdg.add_vertex(t.name)
		}
		cdg.edges.each { |e|
			tdg.add_edges( [hset[e.source].name,hset[e.target].name])
		}
		@debug = 0
		updated_tree = infer2(tdg)

		#writes
		# tdg.write_to_graphic_file('jpg', 'graphs/tdg')
		# updated_tree.write_to_graphic_file('jpg', 'graphs/updated_tdg')
		# @coercion.write_cohercion_tree()
		# @properties.write_tree()

		# @property_tree.write_tree("property_class_tree")
	end
	def infer2(tdg)
		## CONSTRAINTS RESOL
		# print_equations()
		# print_subtypes_equations()

		subs = constrains_resolution(tdg)
		update_union_from_subs(subs)
		s = {}
		total_subs = subs

		while !subs.empty?
			subs.each_pair {|k,v|
				s.merge!(subs_from_property(k,v)) {|key, oldval, newval| newval }
				update_union_from_subs(s)
			}
			subs = s
			total_subs.merge!(subs)
			s = {}
		end

		updated_tree = update_vertices_from_hash(tdg,total_subs)
		unify()
		if total_subs.empty?
			return updated_tree
		end
		debug_tree = update_vertices_from_hash(tdg,total_subs,true)
		debug_tree.write_to_graphic_file('jpg', 'graphs/debug_tree' + @debug.to_s)
		@debug += 1
		v = infer2(updated_tree)
		if v.nil?
			return updated_tree
		end
		return v
	end

	def constrains_resolution(tdg)
		# pp "_constrains_resolution".upcase()
		subs = {}
		passed = []
		1.upto(50) { |i| #For no infinite loop
			vars = tdg.vertices.map { |e| subs.include?(e) ? subs[e] : e} - @constants - passed
			if vars.empty?
				return subs
			end
			v = vars.pop
			# pp "Searching sub for #{v}"
			pgv = predecessors_vars(v,tdg)
			sgv = successors_vars(v,tdg)
			# pp pgv
			if !pgv.empty?
				supremum_pgv = supremum_X(pgv)
				if supremum_pgv.nil?
					raise "FAILED IN RESOLUTON"
				end
				constant_supremum = Constant.new(supremum_pgv)
				res = sgv.map { |e| Constant.new(e) }
						 .all?{ |e| 
						 		@coercion.can_coerce?(constant_supremum,e) }
				if !res
					raise "FAILED IN RESOLUTON"
				end
				subs[v] = supremum_pgv
				# pp "Subbing #{v} for supremum #{supremum_pgv}"
				next
			end
			if !sgv.empty?
				infimum_sgv = infimum_X(sgv)
				if infimum_sgv.nil?
					raise "FAILED IN RESOLUTON"
				end
				constant_infimum = Constant.new(infimum_sgv)
				res = pgv.map { |e| Constant.new(e) }
						 .all?{ |e| 
						 		@coercion.can_coerce?(e,constant_infimum) }
				if !res
					raise "FAILED IN RESOLUTON"
				end
				subs[v] = infimum_sgv
				# pp "Subbing #{v} for infimum #{infimum_sgv}"
				next
			end
			passed.push(v)
		 }
		raise "More than 50 iteration of constraint resolution, probably a cycle in the constraint graph"
		 subs
	end

	#CLASS UPDATERS

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
		@constants.push(c.name)
		c
	end

	def add_coercion(l,r)
		#Must be type not string!
		@coercion.add_coercion(l,r)
	end

	def add_property_of(t1,t2,source)
		@type_source[t2.name] = source
		@properties.add_property_of(t1,t2,source)
	end

	def add_to_property_tree(v,c,type)
		v_with_c = Constant.new("#{c.name}::#{v.name}")
		@property_tree.add_property_of(c,v_with_c,type)
	end

	def set_names_to_type(vars_types)
		@names_to_types = vars_types
	end

	#DEBUG METHODS

	def print_equations
		pp "---equations---"
		@equations.each { |eq|
			pp "#{eq.left.name} == #{eq.right.name}"
		}
	end

	def print_subtypes_equations
		pp "---subtypes---"
		@subtype_equations.each { |st|
			l = @union.parent(st.left).actual_type
			r = @union.parent(st.right).actual_type
			pp "#{l.name} <: #{r.name}"
		}
	end

	#AUX METHODS

	def get_type_from_var(v)
		v.actual_type = @union.parent(v).actual_type  #updating to be sure
		@union.parent(v).actual_type
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
					tail.actual_type = head.actual_type						
				elsif tail.class == Constant
					head.actual_type = tail.actual_type
				else #Compound
					if head.actual_type.class == TypeVar
						head.actual_type = tail.actual_type
					else head.actual_type.name != tail.actual_type.name
						@equations << Equation.new(head.actual_type,tail.actual_type)
					end
				end
		# 		pp "--"
		# pp "#{head.name} is actual_type of #{tail.name}"
		# pp "after updated: #{tail.name}.actual = #{tail.actual_type.name}"
	end

	def init_coercions()
		#all from any
		(CONSTANTS.zip(["Any"]*CONSTANTS.size) - [["Any","Any"]]).each { |xs| 	
			l = Constant.new(xs[0])
			r = Constant.new(xs[1])
			add_coercion(l,r)
		}

		#custom coercions
		add_coercion(Constant.new("int"),Constant.new("string"))
		add_coercion(Constant.new("int"),Constant.new("float"))
	end

	def update_union_from_subs(subs)

		subs.each_pair { |name, val|
			n = @vars_name[name]
			v = @vars_name[val]
			# pp "n = #{n.name}, v=#{v.name}"
			# head = @union.union(n,v)
			# unless head.nil?
			# 	tail = head == n ? v : n
			# 	update_actual_types(head,tail)	
			# end
			add_equation(Equation.new(n,v))
		}
		unify
	end

	def update_subtypes_from_union()
		new_subtypes_equations = []
		@subtype_equations.each { |subeq| 
			new_left = get_type_from_var(subeq.left)
			new_right = get_type_from_var(subeq.right)
			new_subtypes_equations.push(SubType.new(new_left,new_right))
		}
		@subtype_equations = new_subtypes_equations
	end

	def subs_from_property(var_property,const_property)		
		nexts = @properties.get_nexts(var_property)
		subs = {}
		nexts.each {|e|
			property_full = @properties.get_source(e)

			property_main = property_full.split(".")[0..-2].join(".")
			property_main_t = @names_to_types[property_main]
			property_main_t =  get_type_from_var(@names_to_types[property_main])

			class_properties = @property_tree.get_nexts(property_main_t.name)

			property = property_full.split(".").last
			property = property_main_t.name+"::"+property #distinguish between same properties of the different classes
			property_t = @property_tree.get_source(property)
			
			
			
			if !property_t.nil? && class_properties.include?(property)
				#ignore if property not found
				t = get_type_from_var(property_t)
				# add_equation(Equation.new(@vars_name[e].actual_type,t))
				add_equation(Equation.new(get_type_from_var(@vars_name[e]),t))

				subs[e] = t.name
			else
				pp ">>>>Warning: property #{property} in #{property_full}::#{property_main_t.name} not found<<<<"
			end
		}
		# pp "Found subs from properties #{subs}"
		subs
	end

	#HELPER METHODS FOR ALGORITHM (GRAPH RELATED?)

	def to_graph
		dg = RGL::DirectedAdjacencyGraph[]
		@subtype_equations.each { |seq|
			l = get_type_from_var(seq.left)
			r = get_type_from_var(seq.right)
			# l = @union.parent(seq.left).actual_type
			# r = @union.parent(seq.right).actual_type
			dg.add_edges([l.name,r.name])
		}
		dg
	end

	def type_condensation(set, hset)
		if set.size == 1
			t = set.detect {|e| true }
			t = @vars_name[t]
			hset[set] = t
			t
		else
			new_t = VarUtils.gen_type
			hset[set] = new_t
			new_t
		end
	end

	def can_cycle_elim?(dg)
		dg.cycles.each {|cycle|
			cycle = cycle - (cycle - @constants)
			if !@coercion.all_coherce?(cycle)
				raise "Subtype Error"
			end
		}
	end

	def update_vertices_from_hash(dg,h, naming = false)
		new_dg = RGL::DirectedAdjacencyGraph[]
		edges = dg.edges.map { |edge| edge.to_a }.map{ |edge|
			if naming
				s = h.include?(edge[0]) ? h[edge[0]] +  " (#{edge[0]})" : edge[0]
				t = h.include?(edge[1]) ? h[edge[1]] +  " (#{edge[1]})" : edge[1]
			else
				s = h.include?(edge[0]) ? h[edge[0]]: edge[0]
				t = h.include?(edge[1]) ? h[edge[1]]: edge[1]
			end
			[s,t]
		 }
		 new_dg.add_edges(*edges)
		 new_dg
	end

	#PG_v
	def predecessors_vars(v,dg)
		dg.reverse.bfs_search_tree_from(v).vertices & @constants
	end

	#SG_v
	def successors_vars(v,dg)
		dg.bfs_search_tree_from(v).vertices & @constants
	end

	#_
	#T
	def supertype_of(s)
		@coercion.supertype_of(s)
	end

	#T_
	def subtype_of(s)
		@coercion.subtypes_of(s)
	end

	# T |_| S 
	def supremum(s,t)
		_t = supertype_of(t)
		_s = supertype_of(s)
		inter = _s & _t
		@coercion.supremum(inter)
	end
	#   _
	#T | | S
	def infimum(s,t)
		_t = subtypes_of(t)
		_s = subtypes_of(s)
		inter = _s & _t
		@coercion.supremum(inter)
	end
	# |_| X
	def supremum_X(xs)
		xs.map!() {|x| Constant.new(x)}
		suptertypes = xs.map() {|x| supertype_of(x)}.reduce(:&)
		@coercion.supremum(suptertypes)
	end
	# _
	#| | X
	def infimum_X(xs)
		xs.map!() {|x| Constant.new(x)}

		# pp "Subtypes of #{xs[0].name} : #{subtype_of(xs[0])}"
		# pp "Subtypes of #{xs[1].name} : #{subtype_of(xs[1])}"
		subtypes = xs.map() {|x| subtype_of(x)}.reduce(:&)
		# pp "Common subtypes: #{subtypes}"
		@coercion.infimum(subtypes)
	end
end


class Coercion
	def initialize
		@coercion_graph =  RGL::DirectedAdjacencyGraph[]
	end

	def add_coercion(v1,v2)
		@coercion_graph.add_edge(v1.name,v2.name)
	end

	def can_coerce?(v1,v2)
		if v1.name == v2.name
			return true
		end
		if @coercion_graph.has_vertex?(v1.name)
			return @coercion_graph.bfs_iterator(v1.name).detect { |e| e  == v2.name } != nil
		end
		false
	end

	def all_coherce?(cycle)
		#Assuming coherc is transitive - add last pair
		if cycle.size < 2
			return true
		end
		cycle << cycle[0]
		cycle.each_cons(2) { |l,r|
			if l != r && !can_coerce?(Constant.new(l),Constant.new(r))
				return false
			end
		}
		true
	end

	def write_cohercion_tree(name='inheritance_tree')
		@coercion_graph.write_to_graphic_file('jpg', 'graphs/' + name)
	end

	def supertype_of(v)
		vs = @coercion_graph.bfs_search_tree_from(v.name).vertices
		if vs.empty?
			[v.name]
		else
			vs
		end
	end

	def subtypes_of(v)
		vs = @coercion_graph.reverse.bfs_search_tree_from(v.name).vertices
		if vs.empty?
			[v.name]
		else
			vs
		end
	end

	def supremum(vs)
		#decide if this gets strings or typevars
		# vs.map! { |v| v.name}
		# pp "Wanted sup for #{vs}"
		all = @coercion_graph.vertices
		dg_vs = @coercion_graph.clone
		dg_vs.remove_vertices(*(all - vs))
		dg_vs_reversed = dg_vs.reverse
		sup = vs.detect {|v| dg_vs_reversed.out_degree(v) == 0 }
		# pp "Found sup #{sup}"
		# dg_vs.write_to_graphic_file('jpg','graphs/test')
		#edge case
		if dg_vs.vertices.size == 1
			return sup
		end
		if sup.nil?
			return nil
		end
		rvs = dg_vs.bfs_search_tree_from(sup).vertices
		if !(rvs - vs).empty?  || !(vs - rvs).empty? #must be equal
			return nil
		end
		return sup
	end

	def infimum(vs)
		@coercion_graph = @coercion_graph.reverse
		# write_cohercion_tree("test_tree_reversed")
		res = supremum(vs)
		@coercion_graph = @coercion_graph.reverse
		res
	end
end

class Properties
	def initialize
		@graph =  RGL::DirectedAdjacencyGraph[]
		@source = {}
	end
	def add_property_of(t1,t2,source="")
		@graph.add_edge(t1.name,t2.name)
		@source[t2.name] = source
	end

	def get_source(t)
		@source[t]
	end

	def get_nexts(t)
		v = t
		if t.class != String
			v = t.name
		end
		if @graph.vertices.include?(v)
			return @graph.adjacent_vertices(v)
		end
		return []
	end

	def write_tree(name='properties_tree')
		@graph.write_to_graphic_file('jpg', 'graphs/' + name)
	end
end
