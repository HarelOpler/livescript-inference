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
		#Adding var to symbol table
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
		@@unifier.add_equation(Equation.new(type,@vars_types[name]))
		@vars_types[name] = type
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



	

	def add_equation(eq)
		@@unifier.add_equation(eq)
	end

	def add_subtype(st)
		@@unifier.add_subtype(st)
	end

	def self.unifier
		@@unifier
	end
	def move_to_class_scope(var)
		@class_scope.add_var(var)
	end

	def print_vars(indent_level)
		@vars_types.each_pair { |v,t|
			types = to_actual_type(t)
			puts " "*indent_level + v.to_s + " : " + types.name
		}
		@next_scopes.each { |scope| scope.print_vars(indent_level+1) }
	end

	def to_actual_type(t)
		if t.class != Compound
			type =  @@unifier.parent(t.name).actual_type
			if type.class != Compound
				return type
			end
			return to_actual_type(type)
		end

		head = to_actual_type(t.head)
		tail = to_actual_type(t.tail[0])
		return Compound.new(head,[tail],[])
		

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