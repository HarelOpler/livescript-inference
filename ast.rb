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
		Node.scope.print_vars(0)


		
		pp "---equations---"
		Scope.unifier.unify
		pp "---subtypes---"
		Scope.unifier.print_subtypes_equations

		Node.scope.print_vars(0)
	end
end