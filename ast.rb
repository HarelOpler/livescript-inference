require "./nodes.rb"
require "./scope.rb"

class Ast
	attr_accessor :defined_vars
	def initialize(ast_json)
		Node.scope = ClassScope.new("__global__") 
		@head= parseAstFromJsonToNodes(ast_json)
	end

	def get_vars
		@head.get_vars
		pp "____BEFORE____"
		puts "\n\nPrinting vars\n\n"
		Node.scope.print_vars(0)
		puts "\n\nPrinting subtypes equations\n\n"

		Scope.unifier.print_subtypes_equations

		puts "\n\n\n"
		pp "____AFTER____"
		puts "\n\nInfering\n\n"
		Node.scope.infer
		puts "Printing resolved vars"
		# Scope.unifier.infer why calling it twice?
		# Scope.unifier.print_subtypes_equations
		Node.scope.print_vars(0)
	end
end