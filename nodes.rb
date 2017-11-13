require './unify.rb'

class Node
	@@scope = nil
	attr_accessor :type, :value, :prev
	def next(ast_jsno)
		@error = "unidentified node"
	end

	def self.scope
		@@scope
	end
	def self.scope=(scope)
		@@scope=scope
	end

	def get_vars()
		raise NotImplementedError
	end

	def value
		raise NotImplementedError
	end
end


class Block < Node
	def next(ast_json)
		@lines = []
		ast_json["lines"].each { |inner_ast|
			@lines << from_class(inner_ast)
		}
	end

	def get_vars()
		@lines.each { |line|
			line.get_vars()
		}
		# Ignore the dumym function after a block starts
		unless @lines[-1].class == Fun && @lines[-1].is_class_function
			@value = @lines[-1] #last line
			if @value.nil?
				@type = Constant.new("unit")
			else
				@type = @value.type
			end
		end
	end
	def value
		@value
	end
end

class Class_ < Node
	def next(ast_json)
		@name = ast_json["title"]["value"]
		@body = from_class(ast_json,"fun") # mark Fun as class body
		@body.is_class_function = true
	end

	def get_vars()
		@@scope = @@scope.scope(ClassScope.new(@name))
		@body.get_vars()
		@@scope = @@scope.unscope
	end
	def value()
		@name
	end
end

class Fun < Node
	attr_accessor :is_class_function, :name
	def initialize
		@is_class_function = false
	end
	def next(ast_json)
		@body = from_class(ast_json["body"])
		@params = ast_json["params"].map { |param|
			from_class(param)
		 }
	end
	def get_vars()
		if !@is_class_function
			@name = new_fun()
			@@scope.add_var(@name)
			@@scope = @@scope.scope(FunctionScope.new)
		end


		@params.each { |p| 
			p.get_vars
		 }
		@body.get_vars

		if !@is_class_function
			return_type = @params.size > 0 ? @params.map { |p| 
				# I get Chain here... need to determine type
				p.type.name }.join("->") : "unit"
			@type = return_type +"->"+ @body.type.name
			@@scope = @@scope.unscope
			@type = @@scope.update_type(@name,@type)
		end
	end
	def value
		@type
	end
	@@counter = 0
	def new_fun()
		@@counter+=1
		"->"+ @@counter.to_s
	end
end

class Var < Node
	attr_accessor :value
	def next(ast_json)
		@value = ast_json["value"]
		@newed = ast_json["newed"]
	end

	def get_vars()

		if @newed.nil?
			prev_type = @@scope.search(@value)
			@type = prev_type.nil? ? @@scope.add_var(@value) : prev_type
		else
			@type = Constant.new(@value)
			@@scope.add_var_unifier(@type)
		end
	end
	def value()
		@value
	end
end

class Obj < Node
	def next(ast_json)
		@items = []
		ast_json["items"].each { |inner_prop|
			@items = from_class(inner_prop)
		}
	end

	def get_vars()
		@items.each { |item| item.get_vars() }
	end
end

class Prop < Node
	def next(ast_json)
		@key = from_class(ast_json,"key")
		@val = from_class(ast_json,"val")
	end

	def get_vars()
		@key.get_vars()
		@val.get_vars()
	end
end

class Literal < Node
	def next(ast_json)
		@value = ast_json["value"]
	end
	def get_vars()
		# Temporary for simple literals and naive checks
		if @value == "true" || @value =="false"
			@type = "bool"
		elsif @value.to_i.to_s == @value
			@type = "int"
		elsif @value.to_f.to_s == @value
			@type = "float"
		elsif @value == "null"
			@type = "null"
		else
			@type = "string"
		end
		@type = Constant.new(@type)
	end
	def value
		@value
	end
end

class Chain < Node
	attr_accessor :head, :tails
	def next(ast_json)		
		@head = from_class(ast_json,"head")

		@tails = ast_json["tails"].map{ |node_json| 
			n = from_class(node_json)
			n.prev = self
			n
		}
	end

	def get_vars
		@head.get_vars()
		@tails.each { |e| e.get_vars }
		@tails.each_with_index { |e,i|
			if e.class == Index
				# pretty this up.....
				if e.prototype && @tails[i+1].key.name != "Array"
					@@scope.update_type(@head.value, @tails[i+1].key.name)
				elsif @head.value == "this"
					@@scope.move_to_class_scope(e.key.name)
				end
				
				if e.is_array
					var = Constant.new(@tails[i+1].key.it.value)
					if var.name == "_"
						var = @@scope.gen_type()
						@@scope.add_var_unifier(var)
					end
					new_type = Compound.new(Constant.new("Array"),[var],[var]).name
					@@scope.update_type(@head.value, new_type)
				end
			end
		}
		if @tails[0].class == Index && @tails[0].is_paren
			e = @tails[0]
			@type = e.inner_type
			eq = Equation.new(@head.type,e.type)
			@@scope.add_equation(eq)
		elsif @tails[0].class == Call
			@type = @tails[0].type
		else
			@type = @head.type
		end
	end
end

class Index < Node
	attr_accessor :prototype, :key, :is_paren, :inner_type, :is_array
	def next(ast_json)
		@key = from_class(ast_json,"key")
		@is_paren = false
	end
	def get_vars()
		@key.get_vars()
		if @key.class == Key
			if @key.name == "prototype"
				@prototype = true
			end
			if @key.name == "Array"
				@is_array = true
			end
		elsif @key.class == Parens
			@is_paren = true
			@inner_type = @key.inner_type
		end
		@type = @key.type

	end
end

class Key < Node
	attr_accessor :name
	def next(ast_json)
		@name = ast_json["name"]
	end
	def get_vars()
	end
end

class Assign < Node
		def next(ast_json)
			@left = from_class(ast_json,"left")
			@right = from_class(ast_json,"right")
		end

		def get_vars()
			@left.get_vars()
			@right.get_vars()
			@type = @left.type
			@@scope.add_equation(Equation.new(@left.type,@right.type))

		end
		def value()
			@right.value()
		end
end

class Parens < Node
	attr_accessor :inner_type, :it
	def next(ast_json)
		# TODO: fix parens
		@it = from_class(ast_json["it"])
	end
	def get_vars
		@it.get_vars
		@inner_type = @@scope.gen_type
		@@scope.add_var_unifier(@inner_type)
		@type  = Compound.new(Constant.new("Array"),[@inner_type],[@inner_type])
		@@scope.add_var_unifier(@type)
	end
end

class Call < Node
	@@return_var = 0
	def next(ast_json)
		@args = []
		ast_json["args"].each { |e|
			@args << from_class(e)
		}
	end
	def get_vars()
		
		type = @@scope.search(@prev.head.value)
		if type.nil?
			raise ArgumentError "#{@prev.head.value} not found"
		end
		@args.each { |argument| 
			argument.get_vars() 
		}

		new_var = @@scope.gen_type()
		@@scope.add_var_unifier(new_var)
		args_type = @args.map {|argument| argument.type.name }.join("->") + "->" + new_var.name
		@@scope.add_equation(Equation.new(type, Equation.from_string(args_type, Scope.unifier))) #pretty this up		
		@type = new_var
	end
end

class Unary < Node
	def next(ast_json)
		#TODO: fix Unary
		@it = from_class(ast_json["it"])
	end
	def get_vars()
		@it.get_vars
		@type = @it.type
	end

end

class Binary < Node
	BOOL_OP = ["===", "<", ">", "<=", "=>" , "!=="]
	def next(ast_json)
		@first = from_class(ast_json["first"])
		@second = from_class(ast_json["second"])
		@op = ast_json["op"]
		
	end
	def get_vars
		@first.get_vars
		@second.get_vars
		x = Equation.new(@first.type, @second.type)
		@@scope.add_equation(x)
		pp @op
		pp x

		if BOOL_OP.include?(@op)
			@type = Constant.new("bool")
		else
			@type = @first.type
		end
		@value = @first
		
	end
end

class Arr < Node
	def next(ast_json)
		@items = ast_json["items"].map { |item| from_class(item) }
	end

	def get_vars
		@items.each { |item| item.get_vars }
		vars = @items.each { |item| item.type     }
		arr_type = Constant.new("Array")
		@@scope.add_var_unifier(arr_type)
		@items.each_cons(2) { |l,r| @@scope.add_equation(Equation.new(l.type,r.type))}
		@type = Compound.new(arr_type,[@items[0].type],vars)
		@@scope.add_var_unifier(@type)
	end
end

class Return < Node
	def next(ast_json)
		@it = from_class(ast_json["it"])
	end
	def get_vars()
		@it.get_vars
		@type = @it.type
	end
end


class If < Node
	def next(ast_json)
		@if = from_class(ast_json["if"])
		@else = from_class(ast_json["else"])
		@then = from_class(ast_json["then"])
	end
	def get_vars()
		@if.get_vars
		@else&.get_vars
		@then.get_vars
		@type = @then.type
	end
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
	"Binary" => Binary,
	"Arr" => Arr,
	"Return" => Return,
	"If" => If
}
CLASSES.default=Node


def from_class(js,key="")
	node = nil
	if js.nil?
		return nil
	end

	if key==""
		node = CLASSES[js["type"]].new
		node.next(js)
	else
		node = CLASSES[js[key]["type"]].new
		node.next(js[key])
	end
	node

end

