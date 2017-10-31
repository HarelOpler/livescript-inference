require "pp"
require "json"
require "./ast.rb"

if ARGV.size == 0
	puts("File name missing")
	exit()
end

ls_file = ARGV[0]
if ARGV[0].split('.')[-1] != 'ls'
	puts("Must be a livescript file")
	exit()
end

ls_file = ARGV[0]
ast = `lsc --ast --json #{ls_file}`	
if ast == ""
	exit()
end



ast_j = JSON.parse(ast)
# pp ast_j
ast = Ast.new ast_j
ast.get_vars
puts "--------------------------------------------------------------------------------------------------------------"
# pp ast
puts "--------------------------------------------------------------------------------------------------------------"


