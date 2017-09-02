#notes to self:
require "./var.rb"

class ScopeCollection
	attr_accessor  :scopes, :ignore_next_function_scope
	@@classes = {}
	def initialize()
		@scopes = []
		@scope_order = [ClassScope.new("global")]
		@current_class_scope = @scope_order.first
		@scopes << @current_class_scope
		@ignore_next_function_scope = false
	end

	def scope(new_scope)
		new_scope.prev_scope = current_scope
		new_scope.prev_class_scope = @current_class_scope
		@scopes << new_scope
		@scope_order << new_scope

		if new_scope.class == ClassScope
			@current_class_scope = new_scope
			@ignore_next_function_scope = true
		end
	end

	def unscope
		scope = @scope_order.pop
		if scope.class == ClassScope
			@scope_order.reverse_each { |s|
				if s.class == ClassScope
					@current_class_scope = s
					break
				end
			}
		else #scope is functionscoep
			var = scope.to_var
			@scope_order.last.add_var_aux(var, var.type)
		end
	end

	def current_scope
		@scope_order[-1]
	end

	def self.classes
		@@classes
	end
end

class Scope
	attr_accessor :vars, :is_this, :is_prop, :is_parens,
				  :name, :prev_scope, :prev_class_scope, :last_var, :is_next_type
	def initialize(name)
		@name = name
		@vars = []
	end

	def add_var(name,type = "")

		var = Variable.new(name)

		if @is_next_type
			@is_next_type = false
			@last_var.set_type(name)
			return
		end

		if @is_parens
			@is_parens = false
			@last_var.in_parens(name)
			return
		end

		if @vars.include?(var) or (@prev_scope.instance_of? ClassScope and @prev_scope.vars.include?(var))
			#deal with reassign or reuse
			return 
		end

		type_variable = Type.new(type)
		add_var_aux(var,type_variable)
	end

	def add_var_aux(var, type_var)
		@last_var = var
		if @vars.include?(var) or (@prev_scope.instance_of? ClassScope and @prev_scope.vars.include?(var))
			#deal with reassign or reuse
			return 
		else
			var.type = type_var
		end

		if @is_this
			@is_this = false
			prev_class_scope.add_var_aux(var, type_var)
			ScopeCollection.classes[@prev_class_scope.name] << var
		else
			@vars << var
		end
	end

	def add_key(name,type="")
		# check if the class of the type of @last_var has a var with /name/
		# if yes dont add ,otherwise add. should still set last_var to it.
		# for that I need a table of class_name => vars in it
		klass = ScopeCollection.classes[@last_var&.type&.name]
		tmp_var = Variable.new(name)
		var = klass&.find { |e| e ==  tmp_var }
		if var
			@last_var = var
			return
		end
		add_var(name,type)
	end

end

class ClassScope < Scope
	def initialize(name)
		super
		ScopeCollection.classes[name] = []
		self
	end
end

class FunctionScope < Scope
	attr_accessor :params, :param_mode
	@@counter = 0
	def initialize(params)
		@params = []
		super
	end
	def add_var(name,type = "")
		if @param_mode
			if @is_next_type
				@is_next_type = false
				@last_var.set_type(name)
				return
			end
			type_variable = Type.new(type)
			var = Variable.new(name)
			@params << var
			add_var_aux(var, type_variable)
		else
			super
		end

	end 
	def to_var
		var = Variable.new("->" + @@counter.to_s)
		@@counter+=1
		var.type = Type.function(@params, @last_var)
		var

	end
end