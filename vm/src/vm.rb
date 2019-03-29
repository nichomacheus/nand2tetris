require_relative 'parser'

# global variable acting as as LIFO stack for keeping 
# track of function scopign
FUNCTION = [] 

def handleInput()
	# grab the arguments you gave
	inputs = ARGV
	# if there is no file to read from return and error
	if !inputs[0] then puts "Error, you must specify a filename or directory."; return end
	# an array to store the files we'll be parsing
	files = []
	# if the path is to a file, strip comments and whitespaces and snag the lines & filename
	if File.file?(inputs[0]) && inputs[0][-3..-1] == ".vm" then files << handleFile(inputs[0])
	# if the path is to a directory
	elsif File.directory?(inputs[0])
		# for every file in the directory strip comments and whitespaces and snag lines & filename
		# if file is . or .. it's not a valid file -- skip
		Dir.foreach(inputs[0]) do |item|
			next if item == '.' or item == '..'
			files << handleFile(inputs[0]+"/"+item) if File.file?(inputs[0]+"/"+item) && item[-3..-1] == ".vm"
		end 
	else puts "There was an issue finding the file you specified. Please try again."; return end
	# if the path was a file, trip the ending (.vm)
	pth = File.file?(inputs[0]) ? inputs[0][0...-3] : inputs[0].chomp('/')+"/"+inputs[0].chomp('/').split("/")[-1]
	puts pth
	# create an output file
	output = File.new(File.expand_path(pth+'.asm'),'w')
	return {in: files, out: output}
end

# line is the text on the given line, f is the name of the file (defaults to nil),
# i is the line #. This function returns the assembly code of the line
def parseLine(line,f=nil,i)
	# get the command type of the line 
	type = commandType(line)
	# if the type is not an array or the command doesnt have a type, throw an error
	if type.class != Array || type.length == 0 then return -1 else args = arg(line,type[0]) end
	# if the first element of the array is a hash --> its arithmentic
	if type[0].class == Hash then code = writeArithmetic(type[0],i)
	elsif type.length != 1 then return -2
	# if theres only 1 type and its push or pop 
	elsif ['push','pop'].include?(type[0]) then code = mac(type[0] == 'push',args[0],args[1],f)
	else 
		# this is another type that we should handle in future assignments
		t = [:func,:call,:ret,:label,:goto].select{|x| type[0].include?(x.to_s)}
		if t && t.length == 1 then code = method(t[0]).call(args,i)
			# unrecognized type -- throw error
		else return -3 end
	end
	return code
end

# route an arithmetic command to the appropriate place
def writeArithmetic(cmd,ln)
	case cmd[:c]
	when 'add','sub','and','or' then l = arith(cmd[:s])
	when 'neg','not' then l = neginv(cmd[:s])
	when 'gt','lt','eq' then l = glte(cmd[:s],ln)
	else return -1 end 
	return l
end

# b is either "+" if add, "-" if sub, "&" if and "|" if or, opt can 
# change where we save the arith value (either D or M)
def arith(b,opt="M") return "@SP\nAM=M-1\nD=M\nA=A-1\n"+opt+"=M"+b+"D\n" end

# b is either "!" if not or "-" if neg 
def neginv(b) return "@SP\nA=M-1\nM="+b+"M\n" end

# computed gt, lt, and eq. arguments are: 
# b - the symbol corresponding to the command i.e. gt -> 'JGT', 
# lt -> 'JLT', eq => 'JEQ'. ln is the line number. 
def glte(b,ln)
	return arith("-","D")+
	"@T"+ln.to_s+"\nD;"+b+"\n@SP\nA=M-1\nM=0\n@CT."+
	ln.to_s+"\n0;JMP\n(T"+ln.to_s+")\n@SP\nA=M-1\nM=-1\n(CT."+ln.to_s+")\n"
end

# memory access commands go here -- arguments are: 
# dir - boolean, true if push, false if pop; sgmt - memory segment
# v - the 2nd argument in the command; opt - file name 
def mac(dir,sgmt,v,opt=nil)
	# if dir, its a push command, o.w. its a pop
	ret = dir ? "@SP\nA=M\nM=D\n@SP\nM=M+1\n" : "@SP\nAM=M-1\nD=M\n"
	case sgmt
	when "static"
		ret = dir ? "@"+opt+"."+v+"\nD=M\n"+ret : ret + "@"+opt+"."+v+"\nM=D\n"
	when "constant", "temp"
		t = sgmt == "temp" ? [(v.to_i + 5).to_s,'M'] : [v,'A']
		# push: D = RAM[t] or D = t (if constant) then push; pop: RAM[t] = RAM[SP]
		ret = dir ? "@"+t[0]+"\nD="+t[1] +"\n"+ret : ret+"@"+t[0]+"\nM=D\n"
	when "this","that","local","argument"
		# yes this double ternary is gross, but it shortens the code considerably
		tag = "thisthat".include?(sgmt) ? sgmt.upcase : (sgmt == "local" ? "LCL" : "ARG")
		# D or A = RAM[tag]+v  
		t = "@"+tag+"\nD=M\n@"+v+"\n"+(dir ? 'A': 'D')+"=D+A\n"
		ret = dir ? 
		# D = RAM[D] then RAM[SP] = D
		t+"D=M\n"+ret : 
		# RAM[13] = D then RAM[RAM[13]] = RAM[SP]
		t+"@13\nM=D\n"+ret+"@13\nA=M\nM=D\n" 
	when "pointer"
		t = v == "1" ? "@THAT\n" : "@THIS\n"
		ret = dir ? t+"D=M\n"+ret : ret+t+"M=D\n"
	else return -1 
	end
	return ret
end

# handling of a call command 
def call(args,i)
	FUNCTION << args[0]
	tag = "return-address"+i
	lines = "@"+tag+"\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
	lines += ['LCL','ARG','THIS','THAT'].map{|x| pushaddr(x)}.join("")
	lines += "@SP\nD=M\n@"+(args[1].to_i+5).to_s+"\nD=D-A\n@ARG\nM=D\n"
	lines += "@SP\nD=M\n@LCL\nM=D\n"
	lines += goto([args[0],false],i,true)
	lines += "(" + tag + ")"
	# return address label goes here
	FUNCTION.pop
	return lines

end

# handling of a function command
def func(args,i)
	lines = label(args[0],i,true)
	# compute once for efficiency
	val = mac(true,'constant',"0")
	for i in 0...args[1].to_i
		lines += val
	end
	return lines
end

# handling of a return command
def ret(args,i)
	lines = "@LCL\nD=M\n@FRAME\nM=D\n@5\nA=D-A\nD=M\n@RET\nM=D\n"
	lines += mac(false,'argument',"0")
	lines += "@ARG\nD=M+1\n@SP\nM=D\n"
	lines += indc("THAT","FRAME","1")
	lines += indc("THIS","FRAME","2")
	lines += indc("ARG","FRAME","3")
	lines += indc("LCL","FRAME","4")
	lines += "@RET\nA=M\n0;JMP\n"
end

# handling of a goto / goto-if command
def goto(args,i,bool=false)
	tag = bool ? args[0] : (FUNCTION.length > 0 ? FUNCTION[-1]+"$"+args[0] : args[0])
	if args[1] then return "@SP\nAM=M-1\nD=M\n@"+tag+"\nD;JNE\n"
	else return "@"+tag+"\n0;JMP\n" end
end

# handling of a label command
def label(args,i,bool=false)
	if bool then return "(" + args + ")\n"
	else return "(" + (FUNCTION.length > 0 ? FUNCTION[-1]+"$"+args[0] : args[0]) + ")\n" end
end

# helper function that pushes the address pointed to
# by a variable being used as a 'pointer' to the stack
def pushaddr(x)
	return "@"+x+"\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
end

# helper function that sets the RAM[target] = RAM[origin-v]
def indc(target,origin,v)
	return "@"+origin+"\nD=M\n@"+v+"\nD=D-A\nA=D\nD=M\n@"+ target+"\nM=D\n"
end

# takes the array of hashes of corresponding to files as input arg & output file as output arg
def vm(input,output)
	# line index
	i = 1
	# bootstrap 
	if input.any?{|x| x[:file] == "Sys"}
		output.puts("@256\nD=A\n@SP\nM=D\n")
		output.puts(parseLine("callSys.init0","origin","0"))
	end
	# iterate through each of the hashes with lines & filename
	input.each{|x| 
		# iterate through each of the lines in a given file
		x[:lines].each{|y|
			# grab the assembly representing a given line 
			ln = parseLine(y,x[:file],i.to_s)
			# if there is output and its valid then write it 
			# to the output file 
			if ln && ln.class == String then output.puts ln
			# otherwise log the occurrence of an error and break
			else puts "Error parsing in line "+i.to_s+". Returned error "+ln.to_s; return -1
			end
			i += 1
		}
	}
	# throw a loop at the end of the output file for style
	output.puts "(CTSLOOP)\n@CTSLOOP\n0;JMP\n"
	puts "Successfully parsed " + i.to_s + " lines."
end

# execution
files = handleInput()
vm(files[:in],files[:out]) if files 


