require './unify.rb'
require './vars.rb'
SEPERATOR = "$$$"
class Node
	@@scope = nil
	attr_accessor :type, :value, :prev
	def parseNextNode(ast_jsno)
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
	def parseNextNode(ast_json)
		@lines = []
		ast_json["lines"].each { |inner_ast|
			@lines << parseAstFromJsonToNodes(inner_ast)
		}
	end

	def get_vars()
		@lines.each { |line|
			line.get_vars()
		}
		# Ignore the dummy function after a block starts
		unless @lines[-1].class == Fun && @lines[-1].is_class_function
			@value = @lines[-1] #last line
			if @value.nil?
				@type = Constant.new("unit") #or undefined?
			else
				@type = @value.type
			end
		end
	end
end

class Class_ < Node

	def parseNextNode(ast_json)
		@name = ast_json["title"]["value"]
		@body = parseAstFromJsonToNodes(ast_json, "fun") # mark Fun as class body
		@body.is_class_function = true
		@sup = ast_json["sup"]
		if @sup.nil?
			@sup = Constant.new("Any")
		else
			@sup = Constant.new(@sup["value"])
		end
	end

	def get_vars()
		@@scope = @@scope.scope(ClassScope.new(@name))
		@body.get_vars()
		@@scope = @@scope.unscope
		@@scope.add_coercion(Constant.new(@name),@sup)
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
	def parseNextNode(ast_json)
		@body = parseAstFromJsonToNodes(ast_json["body"])
		@params = ast_json["params"].map { |param|
			parseAstFromJsonToNodes(param)
		 }
	end
	def get_vars()
		if !@is_class_function
			@name = new_fun()
			@@scope.add_var(@name)
			alpha,beta,ftype = Compound.create_function_type(@@scope)
			@@scope.update_type(@name,ftype)
			@@scope = @@scope.scope(FunctionScope.new())
		end

		@params.each { |p| 
			p.get_vars
		 }

		@body.get_vars
		c = @body.type

		if @is_class_function
			return
		end

		if (@params.size > 0)
			@params.reverse.map { |p|
							c = Compound.new(p.type,[c],[p.type,c])
							@@scope.add_var_unifier(p.type,c)
						} #folding right over params
		else
			c = Compound.new(Constant.new("unit"),[c],[c])
		end

		@@scope = @@scope.unscope
		@type = @@scope.update_type(@name,c)

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

	attr_accessor :value, :real_name
	def parseNextNode(ast_json)
		@value = ast_json["value"]
		@real_name = @value
		@newed = ast_json["newed"]
	end

	def get_vars()
		if @newed.nil?
			prev_type = @@scope.search(@value)
			@value = @value + SEPERATOR +  @@scope.name
			@type = prev_type.nil? ? @@scope.add_var(@value,@real_name) : prev_type
		else
			@type = Constant.new(@value)
			@@scope.add_var_unifier(@type)
		end
	end
end

class Obj < Node
	def parseNextNode(ast_json)
		@items = []
		ast_json["items"].each { |inner_prop|
			@items << parseAstFromJsonToNodes(inner_prop)
		}
	end

	def get_vars()
		@items.each { |item| item.get_vars() }
	end
end

class Prop < Node
	def parseNextNode(ast_json)
		@key = parseAstFromJsonToNodes(ast_json, "key")
		@val = parseAstFromJsonToNodes(ast_json, "val")
	end

	def get_vars()
		@key.get_vars()
		@val.get_vars()
		@@scope.add_var(@key.name,@key.name)
		@@scope.update_type(@key.name,@val.type)
	end
end

class Literal < Node
	def parseNextNode(ast_json)
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
	def parseNextNode(ast_json)
		@head = parseAstFromJsonToNodes(ast_json, "head")

		@tails = ast_json["tails"].map{ |node_json| 
			n = parseAstFromJsonToNodes(node_json)
			n.prev = self
			n
		}
	end

	def get_vars
		@head.get_vars()
		@tails.each { |e| 
			if e.class != Call
				e.get_vars 
			end
		}
		last_index = @@scope.search(@head.value)
		name_index = @head.value
		@tails.each_with_index { |e,i|
			if e.class == Index
				if e.prototype
					after_index = @tails[i+1].key.name
					update_head_type(after_index)
				else
					t1 = last_index
					name_index = name_index.split(SEPERATOR).first + "." + e.key.name + SEPERATOR + @@scope.name
					last_index = @@scope.add_var(name_index)
					e.type = last_index
					@@scope.add_property_of(t1,last_index,name_index.split(SEPERATOR).first)
				end
			elsif e.class == Call
				e.prev =  i > 0 ? @tails[i-1] : @head
				e.get_vars
			end
				
		}
		@type = @tails[-1].type

	end


	def update_head_type(after_index)
		c = Constant.new(after_index)
		@@scope.add_var_unifier(c)
		@@scope.update_type(@head.value, c)
		@head.type = c
		pp "#{@head.value} is now #{c.name}"
	end
end

class Index < Node
	attr_accessor :prototype, :key, :is_paren, :inner_type, :is_array
	def parseNextNode(ast_json)
		@key = parseAstFromJsonToNodes(ast_json, "key")
		@is_paren = false
	end
	def get_vars()
		@key.get_vars()
		if @key.class == Key
			if @key.name == "prototype"
				@prototype = true
			end
		elsif @key.class == Parens
			@is_paren = true
			@inner_type = @key.inner_type
		end
	end
	def head
		self
	end
	def value
		@key.name
	end
end

class Key < Node
	attr_accessor :name
	def parseNextNode(ast_json)
		@name = ast_json["name"]
	end
	def get_vars()
	end
end

class Assign < Node
		def parseNextNode(ast_json)
			@left = parseAstFromJsonToNodes(ast_json, "left")
			@right = parseAstFromJsonToNodes(ast_json, "right")
		end

		def get_vars()
			@left.get_vars()
			@right.get_vars()
			@type = @left.type
			if @right.type.class == Compound
			# 	#if right side is a function than propogate.. not sure if correct to do so
			# 	# ASK SHACHAR
				@@scope.update_type(@left.value,@right.type)
			else
				# @@scope.add_equation(Equation.new(@left.type,@right.type))
				@@scope.add_subtype(SubType.new(@right.type, @left.type))
			end

		end
		def value()
			@right.value()
		end
end

class Parens < Node
	attr_accessor :inner_type, :it
	def parseNextNode(ast_json)
		# TODO: fix parens
		@it = parseAstFromJsonToNodes(ast_json["it"])
	end
	def get_vars
		@it.get_vars
		@inner_type = VarUtils.gen_type
		@@scope.add_var_unifier(@inner_type)
		@type  = Compound.new(Constant.new("Array"),[@inner_type],[@inner_type])
		@@scope.add_var_unifier(@type)
	end
end

class Call < Node
	@@return_var = 0
	def parseNextNode(ast_json)
		@args = []
		ast_json["args"].each { |e|
			@args << parseAstFromJsonToNodes(e)
		}
	end
	def get_vars()
		type = @prev.type
		# if type.nil?
		# 	type = @@scope.search(@prev.head.value)
		# end
		if type.nil?
			pp @prev
			raise "#{@prev.head.value} not found"
		end

		@args.each { |argument| 
			argument.get_vars() 
		}

		args = @args.map {|argument| argument.type }
		if type.class == TypeVar
			alpha,beta,ftype = Compound.create_function_type(@@scope)
			@@scope.add_equation(Equation.new(ftype,type))
			type = ftype
		end
		@type = generate_constraints(args,type)
	end

	def generate_constraints(args,function_type)
		# args include return var
		# pp args.map { |e| e.name }
		# pp function_type.name
		# pp args
		if args.length <= 0 
			return function_type
		end

		if function_type.class == TypeVar
			#If function_type is T-x and there are still args then T-x := alpha -> beta
			_,_,ftype = Compound.create_function_type(@@scope)
			@@scope.add_equation(Equation.new(function_type,ftype))
			function_type = ftype
		end

		tau = function_type
		sigma = args.first
		alpha,beta,ftype = Compound.create_function_type(@@scope)
		# pp "tau: #{tau.name}, sigma: #{sigma.name}"
		# pp "alpha: #{alpha.name}, beta: #{beta.name}"
		# pp "^^^^^"

		@@scope.add_equation(Equation.new(tau,ftype))
		@@scope.add_subtype(SubType.new(sigma,alpha))
		if function_type.class == Compound
			return generate_constraints(args[1..-1],function_type.tail.first)
		end


		return function_type


	end
end

class Unary < Node
	def parseNextNode(ast_json)
		#TODO: fix Unary
		@it = parseAstFromJsonToNodes(ast_json["it"])
	end
	def get_vars()
		@it.get_vars
		@type = @it.type
	end

end

class Binary < Node
	BOOL_OP = ["===", "<", ">", "<=", "=>" , "!=="]
	def parseNextNode(ast_json)
		@first = parseAstFromJsonToNodes(ast_json["first"])
		@second = parseAstFromJsonToNodes(ast_json["second"])
		@op = ast_json["op"]
		
	end
	def get_vars
		@first.get_vars
		@second.get_vars
		## CHANGES-HAREL-1 - When a binary operation is used (x op y), an equation constraint is not good (will not accept
		# operations between int and float for example). should use the complex constraint that looks for the satisfaction
		# of atleast one of [x <: y, y <: x].
		# as for now, i dont have the infrastructure to create such a constraint so i will only use the constraint x <: y.
		# TODO: add symetric constraint
		createConstraintsForBinaryOp
		# x = Equation.new(@first.type, @second.type)
		# @@scope.add_equation(x)

		if BOOL_OP.include?(@op)
			@type = Constant.new("bool")
		else
			@type = @first.type
		end
		@value = @first
		
	end

	def createConstraintsForBinaryOp()
		@@scope.add_subtype(SubType.new(@first.type, @second.type))
	end
end

class Arr < Node
	## CHANGES-HAREL-2 - list should have a type nameholder T for its type, in order to apply the constraint T <: e for each
	# element e in the list.
	# also changed the way constraints are generated - from requiring equality between all list elements, to requiring
	# subtyping T <: e as mentioned above.
	def parseNextNode(ast_json)
		@items = ast_json["items"].map { |item| parseAstFromJsonToNodes(item) }
	end

	def get_vars
		
		### Temporary code, just to register array as an identifier for subtyping
		@value = "ArrayType"
		prev_type = @@scope.search(@value)
		@value = @value + SEPERATOR +  @@scope.name
		@type = prev_type.nil? ? @@scope.add_var(@value,@real_name) : prev_type
		######
		
		@items.each { |item| item.get_vars }
		vars = @items.each { |item| item.type     }
		arr_type = Constant.new("Array")
		@@scope.add_var_unifier(arr_type)
		# @items.each_cons(2) { |l,r| @@scope.add_equation(Equation.new(l.type,r.type))}
		@items.each {|element| @@scope.add_subtype(SubType.new(element.type,@type))}
		@type = Compound.new(arr_type,[@type],vars)
		@@scope.add_var_unifier(@type)
	end
end

class Return < Node
	def parseNextNode(ast_json)
		@it = parseAstFromJsonToNodes(ast_json["it"])
	end
	def get_vars()
		@it.get_vars
		@type = @it.type
	end
end


class If < Node
	def parseNextNode(ast_json)
		@if = parseAstFromJsonToNodes(ast_json["if"])
		@else = parseAstFromJsonToNodes(ast_json["else"])
		@then = parseAstFromJsonToNodes(ast_json["then"])
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

