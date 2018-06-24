require './unify.rb'
require './vars.rb'
require './block.rb'
require './class'
require './fun'
require './var'
require './obj'
require './prop'
require './literal'
require './chain'
require './index'
require './key'
require './assign'
require './parens'
require './call'
require './unary'
require './binary'
require './arr'
require './return'
require './if'
require './node'
SEPERATOR = "$$$"

CLASSES={
	"Block" => Block,
	"Class" => Class_,
	"Fun" => Fun,
	"Var" => Var,
	"Obj" => Obj,
	"Prop" => Prop,
	"Literal" => Literal,
	"Chain" => Chain,
	"Index" => Index,
	"Key" => Key,
	"Assign" => Assign,
	"Parens" => Parens,
	"Call" => Call,
	"Unary" => Unary,
	"Binary" => Binary,
	"Arr" => Arr,
	"Return" => Return,
	"If" => If
}
CLASSES.default=Node


def parseAstFromJsonToNodes(jsonAst, key="")
	node = nil
	if jsonAst.nil?
		return nil
	end

	if key==""
		node = CLASSES[jsonAst["type"]].new
		node.parseNextNode(jsonAst)
	else
		node = CLASSES[jsonAst[key]["type"]].new
		node.parseNextNode(jsonAst[key])
	end
	node

end

