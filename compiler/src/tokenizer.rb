# predefined vars
KEYWORDS = ["class","constructor","function", "method", "field","static","var",
			"int","char","boolean","void","true","false","null","this","let",
			"do","if","else","while","return"]
KEYWORD_CONSTANTS = ['true','false','null','this']
SYMBOLS = ["(",")","[","]","{","}",".",",",";","+","-","*","/","&","|","<",">","=","~"]
OPERATORS = ["+","-","*","/","&","|","<",">","=","~"]
TYPES = ["int","char","boolean","Array"]
CONVERSIONS = [{s: "<", t: "&lt;"},{s: ">",t: "&gt;"},{s:"&", t: "&amp;"}, {s: "\"", t: '&quot;'}]
OPERATOR_TO_VM = {:+ => 'add', :- => 'sub', :* => 'call Math.multiply 2', :/ => 'call Math.divide 2',
				:& => 'and', :| => 'or', :< => 'lt', :> => 'gt', '='.to_sym => 'eq', :~ => 'not'} 

# splits a string on particular characters and 
# eliminates empty entries
def tokenize(file, echars, kchars)
	ret,temp = [],[]
	comment = false
	file.each{|string|
		current = ""
		s = false
		string.each_char{|x| 
			if echars.include?(x) && !s
				ret << current if current != ""
				current = ""
				s = false
			elsif kchars.include?(x) && !s
				ret << current if current != ""
				ret << x 
				current = ""
			elsif x == "\""
				a,b = s ? [x,""] : ["",x]
				s = !s
				ret << current+a if current != ""
				current = b
			else
				if ![" ","\t","","\r","\n"].any?{|y| y == x}
					current += x
				elsif s 
					current += x
				end
			end 

			if ret.length > 1 
				tag = (ret[-2] + ret[-1]).to_s
				if tag == '//' then ret.pop(2); break
				elsif tag == '/*' then ret.pop(2); comment = true; temp = ret.dup
				elsif tag == '*/' then ret = temp; comment = false
				end
			end

		}
		ret << current if current.length > 0
	}
	return ret
end

def to_xml(token)
	type = tokenType(token)
	if !token then return "none" end
	case type
	when "stringConstant"
		token = token.gsub("\"","") if type == "stringConstant"
	when "symbol"
		tag = CONVERSIONS.select{|x| x[:s] == token}[0]
		token = tag[:t] if tag
	end
	if ["(",")","[","]","{","}",",",";"].include?(token) then return '' end
	return "<"+type +"> "+token+" </"+type + ">\n"
end

def tokenType(token)
	tag = Float(token) rescue nil
	if !token then return "none" 
	elsif KEYWORDS.include?(token) then return "keyword"
	elsif SYMBOLS.include?(token) then return "symbol"
	elsif token.include?("\"") then return "stringConstant"
	elsif tag then return "integerConstant"
	else return "identifier" 
	end
end

# takes a file, opens it and strips out the white spaces, blank lines, etc.
def handleFile(f)
	file = File.open(f,'r')
	rem = tokenize(file,[" "],SYMBOLS)
	
	# grab just the file name (not the full path) 
	fl = f.split('/')[-1][0...-5]

	# return a hash with the parsed lines of the file & the file name
	return {:lines => rem, :file => fl}
end

def handleInput(arg = nil)
	# grab the arguments you gave
	inputs = arg ? arg : ARGV
	# if there is no file to read from return and error
	if !inputs[0] then puts "Error, you must specify a filename or directory."; return end
	# an array to store the files we'll be parsing
	files = []
	# if the path is to a file, strip comments and whitespaces and snag the lines & filename
	if File.file?(inputs[0]) && inputs[0][-5..-1] == ".jack" then files << handleFile(inputs[0])
	# if the path is to a directory
	elsif File.directory?(inputs[0])
		# for every file in the directory strip comments and whitespaces and snag lines & filename
		# if file is . or .. it's not a valid file -- skip
		Dir.foreach(inputs[0]) do |item|
			next if item == '.' or item == '..'
			files << handleFile(inputs[0]+"/"+item) if File.file?(inputs[0]+"/"+item) && item[-5..-1] == ".jack"
		end 
	else puts "There was an issue finding the file you specified. Please try again."; return end
	return files
end

def writeXML(obj)
	output = File.new(File.expand_path(obj[:file]+'.vm'),'w')
	output.puts obj[:lines]
end
