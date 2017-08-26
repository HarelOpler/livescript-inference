require "./var.rb"
class Node
	attr_accessor :additional_info, :nexts, :defined_vars
	def initialize()
		@nexts, @additional_info= [], {}
		@defined_vars = Hash.new([])
		@defined_vars["global"] = []
	end
	def next(ast_json)
		# *nothing*
	end
end

class Block < Node
	def next(ast_json)
		ast_json["lines"].each { |inner_ast|
			node = from_class(inner_ast)
			nexts << node
			@defined_vars.merge!(node.defined_vars) {|key, v1, v2| (v1 + v2).flatten.uniq}
		}
	end
end

class Class_ < Node
	def next(ast_json)
		@additional_info[:name] = ast_json["title"]["value"]
		node = from_class(ast_json,"fun")
		@nexts << node
		node.defined_vars.each_pair { |scope, vars|
			@defined_vars[@additional_info[:name]] += vars
		}
	end
end

class Fun < Node
	def next(ast_json)
		ast_json["params"].each { |param|
			node = from_class(param)
			@nexts << node
			if node.instance_of? Chain
				@defined_vars.merge!(node.defined_vars) {|key, v1, v2| v1 + v2}
			end
		  }
		 node = from_class(ast_json["body"])
		 nexts << node
		 @defined_vars.merge!(node.defined_vars) {|key, v1, v2| v1 + v2}
		 remove_locals()
		
	end
	def remove_locals()
		 @defined_vars.each_pair { |_, val|
		 	val.delete_if { |n| !n.is_this }
		}
	end
end

class Var < Node
	def next(ast_json)
		@defined_vars["global"] << [Variable.new(ast_json["value"])]
	end
end

class Obj < Node
	def next(ast_json)
		ast_json["items"].each { |inner_prop|
			node = from_class(inner_prop)
			@nexts << node
			@defined_vars.merge!(node.defined_vars) {|key, v1, v2| v1 + v2}
		}
	end
end

class Prop < Node
	def next(ast_json)
		key = from_class(ast_json,"key")
		@nexts << key
		@nexts << from_class(ast_json,"val")
		@defined_vars = key.defined_vars
		mark_vars_as_this(@defined_vars)
	end
end

class Literal < Node
	def next(ast_json)
		@additional_info[:is_this] = (ast_json["value"] == "this")
	end
end

class Chain < Node
	def next(ast_json)
		@head = from_class(ast_json,"head")
		@tails = ast_json["tails"].map{ |node_json| 
			from_class(node_json)
		}
		get_defined_properties()
		@nexts << @head
		@nexts += @tails
	end
	def get_defined_properties()
		if @head.instance_of? Literal and @head.additional_info[:is_this]
			@defined_vars = @tails.first.defined_vars.each_pair { |_, val|
				val.map! {|v| 
					v.is_this = true
					v
				}
			}
		end
	end
end

class Index < Node
	def next(ast_json)
		node = from_class(ast_json,"key")	
		@defined_vars = node.defined_vars
		@nexts << node
	end
end

class Key < Node
	def next(ast_json)
		@defined_vars["global"] = [Variable.new(ast_json["name"])]
	end
end

class Assign < Node
		def next(ast_json)
			left_node = from_class(ast_json,"left")
			right_node = from_class(ast_json,"right")
			@nexts << left_node << right_node
			@defined_vars = left_node.defined_vars
		end	
end

class Parens < Node
	def next(ast_json)
		node = from_class(ast_json,"it")
		@nexts << node
	end
end

class Call < Node
end

class Unary < Node
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


def mark_vars_as_this(vars)
	vars.each_pair{ |_, val|
				val.map! {|v| 
					v.is_this = true
					v
				}
         }
end