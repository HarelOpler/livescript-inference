require './unify.rb'

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

	def add_var(var)
		#TODO: create a type for the var.
		#TODO: check if var is this. maybe inject code?
		@vars_types[var] = @vars_types[var] || gen_type()
		@vars_types[var]
	end

	def search(var)		
		if vars_types.has_key?(var)
			return vars_types[var]
		end

		if !outer_scope.nil?
			return outer_scope.search(var)
		end
		nil #not found - error?
	end

	def print_vars(indent_level)
		@vars_types.each_pair { |v,t|
			types = get_real_type_rec(t.name)
			puts " "*indent_level + v.to_s + " : " + types
		}
		@next_scopes.each { |scope| scope.print_vars(indent_level+1) }
	end


	def get_inner_arg_in_array(x,c)
			if x.length == 0
				return [x,c]
			end
			if x[0] == "["
				inner, new_c = get_inner_arg_in_array(x[1..-2],c + 1)
				[inner , new_c]
			else
				[x, c]
			end
	end

	def get_real_type_rec(t)
		
		types = t.split("->").map { |arg|
				inner_arg, c = get_inner_arg_in_array(arg,0) #extracts T1 from [[[T1]]]
				"["*c + @@unifier.parent(inner_arg).actual_type.name + "]"*c
			}.join("->")
		if types == t
			return types
		end
		get_real_type_rec(types)
	end

	def update_type(name,type)
		new_type = Equation.from_string(type,@@unifier)
		@@unifier.add_equation(Equation.new(new_type,@vars_types[name]))
		@vars_types[name] = new_type
	end

	@@counter = 0
	def gen_type()
		@@counter+=1
		Equation.from_string("T-" + @@counter.to_s,@@unifier)
	end

	def add_equation(eq)
		@@unifier.add_equation(eq)
	end

	def add_var_unifier(v)
		if v.class == Constant
			@@unifier.add_const(v)
		end
		@@unifier.add_var(v)

	end
	def self.unifier
		@@unifier
	end
	def move_to_class_scope(var)
		@class_scope.add_var(var)
	end

end

class ClassScope < Scope
	attr_accessor :name
	def initialize(name)
		@name = name
		super
	end
	def print_vars(indent_level)
		puts "-----"
		puts "#{" "*indent_level}- #{@name} -"
		super
	end

	def update_class_scope(prev_scope)
		class_scope = self
	end

end

class FunctionScope < Scope
	attr_accessor :head, :params
	def print_vars(indent_level)
		puts "-----"

		puts "->"
		super
	end
	def update_class_scope(prev_scope)
		class_scope = prev_scope.class_scope
	end
	
end