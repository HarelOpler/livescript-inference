require "./var.rb"
require "./symbol_table"
require "./scope.rb"

class Node
	attr_accessor :additional_info, :nexts
	@@scopes = ScopeCollection.new
	def initialize()
		@nexts, @additional_info= [], {}
	end
	def next(ast_json)
		# *nothing*
	end
	def type_defined?
		false
	end

	def self.scopes
		@@scopes.scopes
	end
end

class Block < Node
	def next(ast_json)
		ast_json["lines"].each { |inner_ast|
			node = from_class(inner_ast)
			nexts << node
		}
		if ast_json["lines"].size == 0
			var = Variable.new("unit")
			var.type = Type.new("unit")
			@@scopes.current_scope.last_var = var
		end
	end
end

class Class_ < Node
	def next(ast_json)
		@additional_info[:name] = ast_json["title"]["value"]

		@@scopes.scope(ClassScope.new(ast_json["title"]["value"]))

		node = from_class(ast_json,"fun")
		@nexts << node

		@@scopes.unscope()

	end
end

class Fun < Node
	def next(ast_json)
		if @@scopes.ignore_next_function_scope
			@@scopes.ignore_next_function_scope = false
			node = from_class(ast_json["body"])
		 	nexts << node
		 	return
		end
		scope = FunctionScope.new("->")
		scope.param_mode = true
		@@scopes.scope(scope)
		ast_json["params"].each { |param|
			node = from_class(param)
			@nexts << node
		 }
		 scope.param_mode = false

		 node = from_class(ast_json["body"])
		 nexts << node

		 @@scopes.unscope

	end
end

class Var < Node
	def next(ast_json)
		@additional_info[:value] = ast_json["value"]

		@@scopes.current_scope.add_var(ast_json["value"])
	end
end

class Obj < Node
	def next(ast_json)
		ast_json["items"].each { |inner_prop|
			node = from_class(inner_prop)
			@nexts << node
		}
	end
end

class Prop < Node
	def next(ast_json)
		key = from_class(ast_json,"key")
		@nexts << key
		@nexts << from_class(ast_json,"val")

	end
end

class Literal < Node
	def next(ast_json)
		@@scopes.current_scope.is_this = (ast_json["value"] == "this")
	end
end

class Chain < Node
	def next(ast_json)
		if ast_json["newed"]
			@@scopes.current_scope.is_next_type = true
		end
			
		@head = from_class(ast_json,"head")
		
		@tails = ast_json["tails"].map{ |node_json| 
			from_class(node_json)
		}

		@nexts << @head
		@nexts += @tails
	end
end

class Index < Node
	def next(ast_json)
		node = from_class(ast_json,"key")	
		@additional_info = node.additional_info
		@nexts << node
	end
end

class Key < Node
	def next(ast_json)
		@additional_info[:name] = ast_json["name"]
		if ast_json["name"] == "prototype"
			@@scopes.current_scope.is_next_type = true
		else
			@@scopes.current_scope.add_key(ast_json["name"])
		end
	end
end

class Assign < Node
		def next(ast_json)
			left_node = from_class(ast_json,"left")
			right_node = from_class(ast_json,"right")
			@nexts << left_node << right_node
		end	
end

class Parens < Node
	def next(ast_json)
		@@scopes.current_scope.is_parens = true
		node = from_class(ast_json,"it")
		@nexts << node
	end
end

class Call < Node

end

class Unary < Node
	def next(ast_json)
		@@scopes.current_scope.is_next_type = true
		node = from_class(ast_json,"it")
		@nexts << node
	end
end

class Binary < Node
end


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
	"Binary" => Binary
}
CLASSES.default=Node


def from_class(js,key="")
	node = nil
	if key==""
		node = CLASSES[js["type"]].new
		node.next(js)
	else
		node = CLASSES[js[key]["type"]].new
		node.next(js[key])
	end
	node

end
