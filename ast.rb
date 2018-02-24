require "./nodes.rb"
require "./scope.rb"

class Ast
	attr_accessor :defined_vars
	def initialize(ast_json)
		Node.scope = ClassScope.new("__global__") 
		@head= from_class(ast_json)
	end

	def get_vars
		@head.get_vars
		pp "____BEFORE____"
		Node.scope.print_vars(0)
		Scope.unifier.print_subtypes_equations

		puts "\n\n\n"
		pp "____AFTER____"
		Node.scope.infer
		# Scope.unifier.infer why calling it twice?
		# Scope.unifier.print_subtypes_equations
		Node.scope.print_vars(0)
	end
end