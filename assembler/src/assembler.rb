# determines if a symbol exists
def query_symbol(s) return @symbols.select{|x| x[:name] == s}[0] end

# determine if a string includes and does not include the characters provide in garr and barr resp.
def incl(s,garr,barr=[]) return garr.any?{|x| s.include? x} && !barr.any?{|x| s.include? x} end

# given true returns the string "1", "0" o.w.
def BTI(bool) return bool ? "1" : "0" end

# returns the type of a given command
def commandType(c)
	# if we get an '@' then we know its an A command
	if c[0] == "@" then return 'A'
	# if we see and = or ;, we can assume its a C command
	elsif c.include?("=") || c.include?(";") then return 'C'
	# and if we see something in parens its probably an L command
	elsif c[0] == "(" && c[c.length-1] == ")" && c.length >2 then return 'L'
	# otherwise this command is weird -- throw an error
	else return -1
	end
end

# given an integer, makes an address of BIT length
def make_address_from_int(n)
	# try to make a binary string from the input, but if we cant don't break
	str = "%b" % Float(n) rescue nil 
	# if we actually have a binary string and its not WAY too long...
	if str != nil && str.length <= BIT 
		# add as many zeros as we need to make it a BIT-length string
		return "0"*(BIT-str.length) + str
	# if the input was really weird or out of bounds return one error
	elsif str != nil && str.length > BIT then return -2
	# catch all error
	else return -1
	end
end

# given a symbol,  returns an associated address (either by grabbing an already instantiated
# one, or by instantiating a new one)
def make_address_from_sym(s,ind)
	# make an address from the input index
	ret = make_address_from_int(ind)
	# add our hash to the array of symbols
	@symbols << {:name => s, :address => ret} 
	# return the address
	return ret
end

# computes the destination part of a command
def dest(str)
	# get everything before the '='
	rem = str.slice(0...str.index('=')) rescue nil
	# our possible dests
	dests = ["A","D","M"]
	# if we don't have stuff before the '=''
	if rem == nil 
		return "000"
	# if rem is not nil lets see if its valid -- if not throw an error
	elsif rem.length > 3 || !rem.chars.uniq.all?{|c| dests.include? c}
		return -2
	# otherwise our string is valid, return the appropriate binary string
	else 
		ret = ""
		dests.map{|x| ret += rem.include?(x) ? "1" : "0"}
		return ret
	end
end

# computes the jump part of a command
def jump(str)
	# get everything after the ';'
	rem = str.slice(str.index(';')+1...str.length) rescue nil
	# this is ugly, but it's a functional way to check for errors
	valids = ["JMP","JGT","JGE","JLT","JLE","JNE","JEQ"]
	# in the nil case return 000
	if rem == nil 
		return "000"
	# if invalid, throw an error
	elsif rem == -2 || rem.length > 3 || !valids.include?(rem)
		return -2
	# if the string is valid, compute the resulting binary string 
	elsif rem.length == 3
		ret = ""
		ret += BTI(['M','L','N'].include? rem[1])
		ret += BTI(['E','P'].any?{|x| rem.include? x} && rem[1] != "N")
		ret += BTI(['M','G','N'].include? rem[1])
		return ret
	end
end

# computes the comp part of a command
def comp(rem)
	# get everything in between the '=' and ';' if these characters
	# are there
	str = rem.slice(rem.index('=')+1...rem.length) rescue rem
	str = str.slice(0...str.index(';')) rescue str
	# the string should be less than 4 characters 
	if (str.length < 4)
		# comp logic
		tag = str.include?("M") ? "M" : "A"
		ret = ""
		# a
		ret += BTI(str.include?("M"))
		# c1
		ret += BTI(!str.include?("D") && incl(str,[tag,"-1","1","0"]) )
		#c2
		ret += BTI((str.length < 3 && incl(str,["1","-1",tag])) || 
			(str.length == 3 && ((str[0] == tag && str[2] != "D") || incl(str[1..2],["-"+tag,"|"+tag,"+1"]))))
		# c3
		ret += BTI(!str.include?(tag) && incl(str,["D","-1","1","0"]) )
		# c4
		ret += BTI((str.length < 3 && incl(str,["1","D"]) && str != "-1") || 
			(str.length == 3 && ((str[0] == "D" && str[1..2] == "-1") || incl(str[1..2],["-D","|"+tag,"+1"]))))
		# c5
		ret += BTI((str.length ==1 && incl(str,["0","1","-1"]) ) || (str.length > 1 && incl(str,[str[0]],["!","&","|"])))
		# c6 
		ret += BTI((str.length == 1 && str == "1") || (str.length > 1 && incl(str,[str[0]],["&","-1","+"+tag,tag+"+D"])))
		return ret
	else
		return -1 
	end
end

#############################
# script for reading / file handling
#############################

# handle reading and writing the file
def handleFile()
	# grab the arguments you gave
	inputs = ARGV
	# if there is no file to read from return and error
	if !inputs[0] then puts "Error, you must specify a filename."; return end
	# reads the file at the location if the file exists && if the file has the extention .asm
	if File.file?(inputs[0]) && inputs[0][-4..-1] == ".asm" then file = File.open(inputs[0], 'r') 
	else puts "There was an issue finding the file you specified. Please try again."; return end
	# creates an output file 
	output = File.new(File.expand_path(inputs[0])[0...-4]+'.hack','w')
	return {:in => file, :out => output}
end

# get rid of white spaces and comments and add (SYMBOLS) to the 
# symbol array as we go
def stipWhiteSpace(file)
	# instantiate an array that will hold all the characters without comments
	nocomments = []
	# no comments check
	ln = 0
	file.each{|f|
		# instantiate an empty string to hold good characters
		r = ""
		# if we got the no-comments flag we instantiate flag to hold the number of 
		# sequential occurences of '//' o.w. flag is false
		flag = 0
		# iterates through the characters in the line, hanging onto the good ones
		f.each_char {|char| 
			# if the flag is not false i.e. if it is an integer and it is equal to
			# 2, we remove the '//' add a newline, and break. We add a newline 
			# since we will be cutting off the newline previously occuring in the 
			# line by breaking before getting to the end 
			if flag && flag == 2 then r = r[0...-2]; break end
			# if the character is a '/' and flag is not false, increment flag
			flag += char == "/" ? 1 : 0 if flag 
			# add the character to the return string if it is not a space, a tab, or empty
			r += char if ![" ","\t","","\r","\n"].any?{|x| char == x}
		}
		next if r == ""
		if commandType(r) == 'L'
			make_address_from_sym(r.slice(1...r.length-1),ln) if !query_symbol(r.slice(1...r.length-1))
			next
		end
		ln += 1
		# add the string to the output file if it's nonempty / is not just a newline
		nocomments << r
	}
	return nocomments
end

#############################
# parsing 
#############################

# responsible for creating the binary machine instructions 
# for each line of inputted assembly
def parse(lines,out)
	# line index
	ln = 0
	# iterate through each line of the 
	lines.each do |line|
		# switch statement on the type of the command
		# Note that we do not handle the 'L' case here. This is because
		# this get handled in the stripWhiteSpace function i.e. during
		# the initial file parsing
		case commandType(line)
		when 'A'
			# get rid of the '@' symbol
			line[0] = ''
			# check to see if we can interpret this 
			# line as an integer
			val = make_address_from_int(line)
			# if this statement is true, it means we got an
			# error from make_address_from_int i.e. we gave it a 
			# non-integer-looking argument
			if val.class == Integer
				# does the symbol exist
				bool = query_symbol(line)
				# if yes, get its address, o.w. return false
				val = bool ? bool[:address] : false
				# if the symbol didnt exist, add it and increment the index
				if !val then val = make_address_from_sym(line,@symbol_index); @symbol_index += 1 end
			end
			# if we got an error anywhere in here we'll see this line 
			e = "Address error in line " + ln.to_s
		when 'C'
			# get the result of comp,dest, and jump
			c,d,j = comp(line), dest(line), jump(line)
			# if we didnt get any weird values, create our binary string
			val = "111" + c + d + j if ![c,d,j].any?{|x| x.class == Integer}
			# the error for C commands
			e = "C Command error in line " + ln.to_s
		else
			e = "Unrecognized command error in line "+ ln.to_s 
		end
		ln += 1
		# if the val is recognized, add it to the out array o.w. return an error
		if val then out << val+"\n" else return e end
	end
	return "Successfully parsed "+ lines.length.to_s + " lines of code."
end

#############################
# constants
#############################

# paramters
BIT = 16 
# the index where we begin 'saving' symbols
@symbol_index = 16
# our initial list of symbols 
@symbols = [
	{:name => "SP",:address => make_address_from_int("0")},
	{:name => "LCL",:address => make_address_from_int("1")},
	{:name => "ARG",:address => make_address_from_int("2")},
	{:name => "THIS",:address => make_address_from_int("3")},
	{:name => "THAT",:address => make_address_from_int("4")},
	{:name => "SCREEN",:address => make_address_from_int("16384")},
	{:name => "KBD",:address => make_address_from_int("24576")}
]
# add the R0 - R15 symbols
(0..15).each{|x| @symbols << {:name => "R"+x.to_s, :address => make_address_from_int(x)}}

#############################
# execution  
#############################

files = handleFile()
stripped_file = stipWhiteSpace(files[:in]) if files
puts parse(stripped_file,files[:out]) if files







