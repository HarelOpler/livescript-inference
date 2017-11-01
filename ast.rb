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
		# pp Scope.unifier
		Node.scope.print_vars(0)
		pp "unifing..."
		Scope.unifier.unify
		
		Node.scope.print_vars(0)
	end
end