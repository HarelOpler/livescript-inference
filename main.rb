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

# puts ast

ast_j = JSON.parse(ast)


def isLineArrayIndexGetter(line)
	line['type'] == "Assign" && line['right']['type'] == "Chain" && line['right']['tails'][0]['type'] == "Index"
end

def changeIndexGetToMethodGet(line)
	array = line['right']['head'].clone
	index = line['right']['tails'][0]['key']['it'].clone

	line['right']['head']['value'] = "get"
	line['right']['tails'][0]['type'] = "Call"
	line['right']['tails'][0]['args'] = [array, index]
end

def changeIndexSetToMethodSet(line)
	line['type'] = "Chain"
	headOfChainBefore = line['left']['head'].clone
	array = line['left']['head'].clone
	index = line['left']['tails'][0]['key']['it'].clone
	valueToAssign = line['right'].clone
	line['head'] = {'type' => "Var", 'value' => "set", 'first_line' => headOfChainBefore['first_line'],
									'first_column' => headOfChainBefore['first_column'], 'last_line' => headOfChainBefore['last_line'],
									'last_column' => headOfChainBefore['last_column'], 'line' => headOfChainBefore['line'], 'column' => headOfChainBefore['column']}
	line['tails'] = [{'type' => "Call", 'args' => [array, index, valueToAssign]}]
end

def isLineArrayIndexSetter(line)
	line['type'] == "Assign" && line['left']['type'] == "Chain" && line['left']['tails'][0]['type'] == "Index"
end

ast_j['lines'].each {|line|
	if isLineArrayIndexSetter(line)
		changeIndexSetToMethodSet(line)
	end
	if isLineArrayIndexGetter(line)
		changeIndexGetToMethodGet(line)
	end
}
# pp ast_j
ast = Ast.new ast_j

ast.get_vars
puts "--------------------------------------------------------------------------------------------------------------"
# pp ast
puts "--------------------------------------------------------------------------------------------------------------"

