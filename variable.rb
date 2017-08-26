require "pp"
require "json"
require "./ast.rb"


ls_file = 'sample_file.ls'
ast = `lsc --ast --json #{ls_file}`

ast_j = JSON.parse(ast)
ast = Ast.new ast_j
pp ast.defined_vars


