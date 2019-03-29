require_relative 'tokenizer'

# create a tag from a term, if f is true, return the closing tag
def E(t,f=false) return (f ? "</" : "<") +t+">"+"\n" end

# create the opening and closing tag of an argument tag
# with some stuff (object) in between the opening and closing tags 
def T(tag,object) return E(tag)+object+E(tag,true) end

# enclose in multiple tags
def A(tags,object) return tags.length > 0 ? T(tags[0],A(tags.drop(1),object)) : object end

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

# compiles a term
def compileTerm(lines,i,parent)
	lookahead = lines[i+1] if i < lines.length-1
	pre = to_xml(lines[i])
	# if we see a .,(, or [ coming, handle these appropriately
	if ['.','(','['].include?(lookahead) && pre.include?('identifier')
		i,temp = compileLine(lines,i+1,lookahead == '[' ? ']' : ')',parent)
		return [i+1,T('term',pre+temp+to_xml(lines[i]))]
	# if we see a paren then we know we have an expression and that the entire
	# object should be treated as a big term
	elsif '(' == lines[i] 
		i,temp = compileExpression(lines,i+1,')',parent)
		return [i+1,T('term',pre+temp+to_xml(lines[i]))]
	# if we see a unary opertaor and its acting as such, compile the operand as a term
	elsif ['-','~'].include?(lines[i]) && ["+","-","*","/","&","|","<",">","=","~",'('].include?(lines[i-1])
		i,temp = compileTerm(lines,i+1,parent)
		return [i,T('term',pre+temp)]
	# if we see a comma then we're in an expressionList
	elsif lines[i] == ','
		return [i+1, E('expression',true)+pre+E('expression')]
	# if the token is a term, wrap it in term tag
	elsif (['integerConstant','stringConstant','identifier'] + KEYWORD_CONSTANTS).any?{|y| pre.include?(y)}
			return [i+1,T('term',pre)] 
	# otherwise just return the tag and increment
	else return [i+1,pre]
	end
end

# compiles an expression in a similar way to compileLine 
def compileExpression(lines,i,endchar,parent)
	ret = ""
	while (i < lines.length && !endchar.include?(lines[i]))
		i,temp = compileTerm(lines,i,parent)
		ret += temp
	end
	if ret != "" then ret = T('expression',ret) end
	return [i,ret]
end

# compiles a varDec in a similar way to compileLine
def compileVarDec(lines,i,endchar,parent)
	tempa = to_xml(lines[i])
	i += 1
	while (lines[i] == 'var')
		pre = to_xml(lines[i])
		i,tempb = compileLine(lines,i+1,endchar,parent)
		tempa += T('varDec',pre+tempb)
	end
	return [i,tempa]
end

# compiles a function, constructor, or method statement
def compileFCM(lines,i,parent)
	i,tempa = compileLine(lines,i,'(',parent)
	j,tempb = compileLine(lines,i+1,')',parent)
	k,tempc = compileVarDec(lines,j+1,['while','if','do','return','let','}','var'],parent)
	if lines[k] != '}' then l,tempd = compileLine(lines,k,'}',parent); tempc += T('statements',tempd)+to_xml(lines[l]); k=l
	else tempc += to_xml(lines[k]) end  
	return [k,tempa + to_xml(lines[i]) + T('parameterList',tempb) + to_xml(lines[j]) + T('subroutineBody',tempc)]
end

# parses a given token
def parse(lines,i,parent)
	kw = lines[i]
	pre = to_xml(kw)
	case kw
	when 'return' 
		i,temp = compileExpression(lines,i+1,';','return')
		return [i+1,T('returnStatement',pre+temp+to_xml(lines[i]))]
	when 'class'
		i,temp = compileLine(lines,i+1,['}'], kw)
		return [i+1, T('class',pre+temp+to_xml(lines[i]))]
	when 'static','field'
		i,temp = compileLine(lines,i+1,[';'],kw)
		return [i+1, T('classVarDec',pre+temp+to_xml(lines[i]))]
	when 'let'
		i,temp = compileLine(lines,i+1,[';'],kw)
		return [i+1, T('letStatement',pre+temp+to_xml(lines[i]))]
	when 'while'
		i,temp = compileLine(lines,i+1,['}'],kw)
		return [i+1,T(kw+'Statement',pre+temp+to_xml(lines[i]))]
	when 'if'
		i,temp = compileLine(lines,i+1,['}'],kw)
		if lines[i+1] == 'else'
			j,tempa = compileLine(lines,i+1,['}'],kw)
			temp += to_xml(lines[i]) + tempa
			i = j
		end
		return [i+1,T(kw+'Statement',pre+temp+to_xml(lines[i]))]
	when 'function','constructor','method'
		i,temp = compileFCM(lines,i+1,kw)
		return [i+1,T('subroutineDec',pre+temp)]
	when 'do'
		i,temp = compileLine(lines,i+1,[';'],kw)
		return [i+1,T('doStatement',pre+temp+to_xml(lines[i]))]
	when '='
		i,temp = compileExpression(lines,i+1,[';'],parent)
		return [i,pre+temp]
	when '('
 		j,temp = compileExpression(lines,i+1,[')'],parent)
 		if tokenType(lines[i-1]) == 'identifier' then temp = T('expressionList',temp) end
 		return [j,pre+temp]
 	when '{'
 		if parent != 'class' then i,temp = compileLine(lines,i+1,['}'],parent); return [i,pre+T('statements',temp)] 
 		else return [i+1,pre] end
 	when '['
 		i,temp = compileExpression(lines,i+1,[']'],parent)
 		return [i,pre+temp]
	else return [i+1,pre]
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
	return ret
end 

def route(arg = nil)
	inputs = handleInput(arg)
	inputs.map{|x| 
		x[:lines] = analyze(x[:lines])
		writeXML(x)
	}
end

route()
