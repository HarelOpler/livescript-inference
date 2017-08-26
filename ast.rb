require "./nodes.rb"

class Ast
	attr_accessor :defined_vars
	def initialize(ast_json)
		@head= from_class(ast_json)
		@defined_vars = get_defined_vars()
	end
	def get_defined_vars()
		defined_vars = @head.defined_vars
		classes = defined_vars.keys.delete_if { |var| var=="global" }
		defined_vars["global"] += classes
		defined_vars
	end
end