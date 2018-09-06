require './unify.rb'
require './vars.rb'

class Scope
=begin
	@vars_types  -  A hash table from vars names to their types.
	@outer_scope -  The outer scope of this scope.
	@next_scopes -  A list of scopes representing the next scopes.
					Ordered from left to right such that left is the closest scope.
=end
	attr_accessor :vars_types, :outer_scope, :next_scopes, :class_scope
	@@unifier = Unify.new([],[])
	def initialize(*a)
		@vars_types = Hash.new
		@real_vars_name = Hash.new
		@real_to_vars = Hash.new

		@next_scopes = []
		@class_scope = self
	end

	def scope(next_scope)
		next_scope.outer_scope = self
		@next_scopes << next_scope
		next_scope.update_class_scope(self)
		next_scope
	end

	def unscope
		outer_scope
	end

	def add_var(var,real_name=nil)
		#Adding var to symbol table
		# unless real_name.nil?
		# 	@real_vars_name[var] = real_name
		# 	@real_to_vars[real_name] = var
		# end

		var = var.split(SEPERATOR).first
		@vars_types[var] = @vars_types[var] || @@unifier.add_var(VarUtils.gen_type())
		@vars_types[var]
	end

	def add_var_unifier(*vs)
		#Adding the type variable in unifier
		vs.each { |v| 
			if v.class == Constant
				@@unifier.add_const(v)
			end
			@@unifier.add_var(v)
		}
	end
	
	def update_type(name,type)
		name = name.split(SEPERATOR).first
		# pp @vars_types[name].name
		# pp "searching for #{name}"
		x = search(name)
		# pp self.name
		# pp "found #{x.name}"
		@@unifier.add_equation(Equation.new(type,x))
		@vars_types[name] = type
	end

	def search(var,clss=nil)
		var = var.split(SEPERATOR).first
		if vars_types.has_key?(var) && clss.nil?
			return vars_types[var]
		end
		# if(real_to_vars.has_key?(var) && clss.nil?)
		# 	return real_to_vars[var]
		# end

		if !outer_scope.nil?
			return outer_scope.search(var)
		end
		nil #not found - error?
	end

	def add_equation(eq)
		# if(eq.right.name == "T-6")
		# 	throw "here"
		# end
		@@unifier.add_equation(eq)
	end

	def add_subtype(st)
		@@unifier.add_subtype(st)
	end

	def self.unifier
		@@unifier
	end

	def print_vars(indent_level)
		@vars_types.each_pair { |v,t|
			types = to_actual_type(t)
			if v["->"].nil?
				# real_v = @real_vars_name[v]
				variableName = v.to_s
				if variableName.include? "ArrayType" or variableName.include? "set" or variableName.include? "get"
					# Those identifiers are omitted because they are imaginary. ArrayType_X is created as a space-saver for array types,
					# and set\get are created automatically when an array is accessed as lvalue\rvalue, respectively.
					next
				end
				puts " "*indent_level + variableName + " : " + types.name
			end
		}
		@next_scopes.each { |scope| scope.print_vars(indent_level+1) }
	end

	def to_actual_type(t)
		type = @@unifier.get_type_from_var(t)
		if type.class == Compound
			head = to_actual_type(type.head)
			tail = to_actual_type(type.tail[0])
			return Compound.new(head,[tail],[])
		else
			return type
		end
		# if t.class != Compound
		# 	type =  @@unifier.parent(t.name).actual_type
		# 	if type.class != Compound
		# 		return type
		# 	end
		# 	return to_actual_type(type)
		# end

		# head = to_actual_type(t.head)
		# tail = to_actual_type(t.tail[0])
		# return Compound.new(head,[tail],[])
	end

	def add_coercion(l,r)
		@@unifier.add_coercion(l,r)
	end

	def add_property_of(t1,t2,source)
		@@unifier.add_property_of(t1,t2,source)
	end

	def infer
		@@unifier.set_names_to_type(@vars_types)
		@@unifier.infer
	end

end

class ClassScope < Scope
	attr_accessor :name
	def initialize(name)
		@name = name
		@name_t = Constant.new(@name)
		super
	end
	def print_vars(indent_level)
		puts "-----"
		puts "#{" "*indent_level}- #{@name} -"
		super
	end

	def search(var,clss=nil)
		var = var.split(SEPERATOR).first
		if !clss.nil? && clss == name
			return vars_types[var]
		end
		super(var,clss)
	end

	def update_class_scope(prev_scope)
		class_scope = self
	end

	def add_var(var,real_name=nil)
		v = super(var,real_name)
		if var["->"].nil? #if not a function, add to tree
			@@unifier.add_to_property_tree(Constant.new(var), @name_t,v)
		end
		v
	end

end

class FunctionScope < Scope
	attr_accessor :name
	@@counter = 0
	def initialize()
		@name = "f_" + @@counter.to_s
		@@counter += 1 
		super
	end
	def print_vars(indent_level)
		puts "-----"

		puts "->"
		super
	end
	def update_class_scope(prev_scope)
		class_scope = prev_scope.class_scope
	end
	
end