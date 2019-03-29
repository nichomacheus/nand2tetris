require_relative 'tokenizer'

TABLE = []
COUNTS = {if: 0, while: 0}

# create a tag from a term, if f is true, return the closing tag
def E(t,f=false) return (f ? "</" : "<") +t+">"+"\n" end

# create the opening and closing tag of an argument tag
# with some stuff (object) in between the opening and closing tags 
def T(tag,object) return E(tag)+object+E(tag,true) end

# enclose in multiple tags
def A(tags,object) return tags.length > 0 ? T(tags[0],A(tags.drop(1),object)) : object end

# returns a string of the given COUNTS value for a the supplied tag
# and increments COUNTS[val] -- NOTE: COUNTS is here mainly because
# matching label indices with the JackCompiler made testing easier
def ris(val) ln = COUNTS[val]; COUNTS[val] += 1; return ln.to_s end

# basically iterates through the lines given until the endcharacter 
# is reached, then return the current index and the intervening lines
def compileLine(lines,i,endchar,parent)
	ret = ""
	while (i < lines.length && !endchar.include?(lines[i]))
		i,temp = parse(lines,i,parent)
		ret += temp
	end
	return [i,ret]
end

# get a variable from the list
def getVar(var)
	TABLE.reverse.map{|x| 
		t = x[:vars][var.to_sym]
		if t then return t end
	}
	return nil
end

# add a new variable to the list
def addVar(item,type,kind) 		
	TABLE[-1][:vars][item.to_sym] = {type: type, kind: kind, index: TABLE[-1][kind.to_sym]}
	TABLE[-1][kind.to_sym] += 1
end

# generate a command (push or pop) for a given variable
def genLine(action,var) 
	v = getVar(var)
	return v ?  action+' '+v[:kind]+' '+v[:index].to_s+"\n" : ''
end

# get the Class of the file
def getClass() return TABLE.select{|x| x[:type] == 'class'}[0] end

# compiles a term
def compileTerm(lines,i,parent)
	lookahead = lines[i+1] if i < lines.length-1
	pre = tokenType(lines[i])
	# if we see a  ( lookahead handle here
	if lookahead == '(' && pre == 'identifier'
		i,temp = compileLine(lines,i+1,')',parent)
		return [i+1,temp]
	# do this when we come across a [ lookahead indicating an array
	elsif lookahead == '[' && pre == 'identifier'
		j,temp = compileLine(lines,i+1,']',parent)
		return [j+1, temp+genLine('push',lines[i])+"add\npop pointer 1\npush that 0\n"]
	# do this when we come across a function/method etc (indicated by a lookahead .)
	elsif lookahead == '.' && pre == 'identifier'
		func = lines[i]+lines[i+1]+lines[i+2]
		j,temp = compileLine(lines,i+1,')',parent)
		if getVar(lines[i])
			TABLE[-1][:temp] += 1
			func = getVar(lines[i])[:type]+lines[i+1]+lines[i+2]
			temp += genLine('push',lines[i])
		end
		return [j+1,temp+'call '+func+' '+TABLE[-1][:temp].to_s+"\n"]
	# if we see a paren then we know we have an expression and that the entire
	# object should be treated as a big term
	elsif '(' == lines[i] 
		i,temp = compileExpression(lines,i+1,')',parent)
		return [i+1,temp]
	# if we see a unary opertaor and its acting as such, compile the operand as a term
	elsif ['-','~'].include?(lines[i]) && ["+","-","*","/","&","|","<",">","=","~",'(',','].include?(lines[i-1])
		j,temp = compileTerm(lines,i+1,parent)
		return [j,temp+(lines[i] == '-' ? "neg\n" : "not\n")]
	# if the item is an operator, convert it to the vm operator
	elsif OPERATORS.include?(lines[i])
		j,temp = compileTerm(lines,i+1,parent)
		return [j,temp+OPERATOR_TO_VM[lines[i].to_sym]+"\n"]
	# handle strings
	elsif pre.include?('stringConstant')
		lines[i][0], lines[i][-1] = ['','']
		temp = 'push constant '+lines[i].length.to_s+"\ncall String.new 1\n"
		lines[i].each_char{|x| temp+='push constant '+x.ord.to_s+"\ncall String.appendChar 2\n"}
		return [i+1,temp]
	# increment the # of arguments for each comma
	elsif lines[i] == ',' then TABLE[-1][:temp] += 1; return [i+1, '']
	# push integer constants
	elsif pre.include?('integerConstant') then return [i+1,'push constant '+lines[i]+"\n"]
	# push variables
	elsif pre.include?('identifier') then return[i+1,genLine('push',lines[i])]
	# handle false and null
	elsif ['false','null'].include?(lines[i]) then return [i+1,"push constant 0\n"]
	# handle true
	elsif 'true' == lines[i] then return [i+1,"push constant 0\nnot\n"]
	# handle this
	elsif 'this' == lines[i] then return [i+1,"push pointer 0\n"]
	else return [i+1,'']
	end
end

# compiles an expression in a similar way to compileLine 
def compileExpression(lines,i,endchar,parent)
	ret = ""
	while (i < lines.length && !endchar.include?(lines[i]))
		i,temp = compileTerm(lines,i,parent)
		ret += temp
	end
	return [i,ret]
end

# compiles a varDec in a similar way to compileLine
def compileVarDec(lines,i,endchar,parent)
	while (lines[i] == 'var')
		i,tempb = compileLine(lines,i+1,endchar,'varDec'+lines[i+1])
	end
	return [i,'']
end

# compiles a function, constructor, or method statement
def compileFCM(lines,i,parent)
	i,tempa = compileLine(lines,i,'(',parent)
	j,tempb = compileLine(lines,i+1,')','parameterList')
	k,tempc = compileVarDec(lines,j+2,['while','if','do','return','let','}','var'],parent)
	if lines[k] != '}' then l,tempd = compileLine(lines,k,'}',parent); tempc += tempd; k=l end  
	return [k,tempa  + tempb + tempc]
end

# parses a given token
def parse(lines,i,parent)
	kw = lines[i]
	# handle returns
	if kw == 'return' 
		i,temp = compileExpression(lines,i+1,';','return')
		if temp == '' then temp = "push constant 0\n" end
		return [i+1,temp+"return\n"]
	# handle class
	elsif kw == 'class'
		# instantiate a new class 
		TABLE << {name: lines[i+1], type: 'class', vars: {}, this: 0, static: 0, local: 0, argument: 0, temp: 0}
		i,temp = compileLine(lines,i+1,['}'], kw)
		return [i+1, temp]
	# handle static and field variables
	elsif ['static','field'].include?(kw)
		i,temp = compileLine(lines,i+1,[';'],kw+lines[i+1])
		return [i+1, temp]
	# handle let statements
	elsif kw == 'let'
		tag = lines[i+2] != '[' ? genLine('pop',lines[i+1]) : "pop temp 0\npop pointer 1\npush temp 0\npop that 0\n"
		i,temp = compileLine(lines,i+1,[';'],kw)
		return [i+1, temp+tag]
	# handle while statements
	elsif kw == 'while'
		ln = ris(:while)
		j,tempa = compileLine(lines,i+1,[')'],kw)
		j,temp = compileLine(lines,j+1,['}'],kw)
		tempa += "not \nif-goto WHILE_END" +ln+"\n"
		return [j+1,'label WHILE_EXP'+ln+"\n"+tempa+temp+ "goto WHILE_EXP"+ln+"\n"+"label WHILE_END" + ln + "\n"]
	# handle if statements -- this is more verbose due to the fact that I matched my labels w/ the JackCompiler
	elsif kw == 'if'
		ln = ris(:if)
		i,tempa = compileLine(lines,i+1,[')'],kw)
		i,temp = compileLine(lines,i+1,['}'],kw)
		if lines[i+1] == 'else' then temp += "goto IF_END"+ln+"\n" end
		temp += "label IF_FALSE"+ln+"\n"
		if lines[i+1] == 'else'
			i,tempb = compileLine(lines,i+1,['}'],kw)
			temp += tempb + "label IF_END"+ln+"\n"
		end
		return [i+1,tempa+"if-goto IF_TRUE"+ln+"\ngoto IF_FALSE"+ln+"\nlabel IF_TRUE"+ln+"\n"+temp]
	# handle functions, constructors, and methods
	elsif ['function','constructor','method'].include?(kw)
		COUNTS[:while],COUNTS[:if] = [0,0]
		TABLE << {name: lines[i+2], type: lines[i+1], vars: {}, this: 0, static: 0, local: 0, argument: 0}
		# if we're in a method -- add the this variable
		if kw == 'method' then addVar('this',lines[i+1],'argument') end
		i,temp = compileFCM(lines,i+1,kw)
		func = 'function ' + getClass()[:name]+'.'+TABLE[-1][:name]+' '+TABLE[-1][:local].to_s+"\n"
		if kw == 'constructor' then func += "push constant "+getClass()[:this].to_s+"\ncall Memory.alloc 1\npop pointer 0\n"
		elsif kw == 'method' then func += "push argument 0\npop pointer 0\n" end
		return [i+1,func+temp]
	# handle do statements
	elsif kw == 'do'
		j,temp = compileLine(lines,i+1,[';'],kw)
		if lines[i+2] != '(' && getVar(lines[i+1])
			t = getVar(lines[i+1])[:type]+lines[i+2]+lines[i+3]
			temp = genLine('push',lines[i+1])+temp
			TABLE[-1][:temp] += 1
		elsif lines[i+2] == '(' 
			t = getClass()[:name] +'.'+lines[i+1]
			temp = "push pointer 0\n"+temp
			TABLE[-1][:temp] += 1
		else t = lines[i+1]+lines[i+2]+lines[i+3] end
		return [j+1,temp+ 'call '+t+' '+TABLE[-1][:temp].to_s+"\npop temp 0\n"]
	# = -> expression
	elsif kw == '=' 
		i,temp = compileExpression(lines,i+1,[';'],parent)
		return [i,temp]
	# ( -> expression
	elsif kw == '('
		TABLE[-1][:temp] = 1
 		i,temp = compileExpression(lines,i+1,[')'],'expressionList')
 		if temp == '' then TABLE[-1][:temp] = 0 end
 		return [i,temp]
 	# statements
 	elsif kw == '{' && parent != 'class' 
 		i,temp = compileLine(lines,i+1,['}'],parent)
 		 return [i,temp] 
 	# arrays
 	elsif kw == '['
 		i,temp = compileExpression(lines,i+1,[']'],parent)
 		return [i,temp]
 	# variable declarations
	elsif tokenType(kw) == 'identifier' && parent.include?('varDec') && !TYPES.include?(kw)
		addVar(kw,parent.gsub('varDec',''),'local')
		return [i+1,'']
	# parameter lists (arguments)
	elsif tokenType(kw) == 'identifier' && parent.include?('parameterList') && !TYPES.include?(kw)
		addVar(kw,lines[i-1],'argument')
		return [i+1,'']
	# global variables
	elsif tokenType(kw) == 'identifier' && ['static','field'].any?{|x| parent.include?(x)} && !TYPES.include?(kw)
		addVar(kw,parent.gsub('static','').gsub('field',''),parent.include?('field') ? 'this' : 'static')
		return [i+1,'']
	# arrays (other) 
	elsif lines[i+1] == '[' && tokenType(kw) == 'identifier'
		j,temp = compileExpression(lines,i+1,[']'],parent)
		return [j,temp+genLine('push',lines[i])+"add\n"]
	else return [i+1,'']
	end
end

# iterate through all the lines given
def analyze(lines)
	ret = ""
	i = 0
	while i < lines.length
		i,temp = parse(lines,i,'class')
		ret += temp
	end
	TABLE.pop(TABLE.length)
	return ret
end 

def route(arg = nil)
	c = 0
	inputs = handleInput(arg)
	inputs.map{|x| TYPES << x[:file]}
	inputs.map{|x| 
		c += x[:lines].length
		x[:lines] = analyze(x[:lines])
		writeXML(x)
	}
	puts "Compilation complete. Compiled "+c.to_s+" lines of code from "+inputs.length.to_s+" files.\n"
end

route()