# get rid of white spaces and comments 
def stripWhiteSpace(file)
	# instantiate an array that will hold all the characters without comments
	nocomments = []
	file.each{|f|
		# instantiate an empty string to hold good characters
		r = ""
		# instantiate flag to hold the number of sequential occurences of '/'
		flag = 0

		oflag = [false,false]
		# iterates through the characters in the line, hanging onto the good ones
		f.each_char {|char| 
			break if flag == 2
			# if the character is a '/' and flag is not false, increment flag
			if char == "/" then flag += 1; next  end
			# add the character to the return string if it is not a space, a tab, or empty
			if ![" ","\t","","\r","\n"].any?{|x| char == x}
				r += char
				oflag[1] = true if oflag && oflag[0]
			elsif oflag == nil then next
			elsif char == ' ' && !oflag[0] then oflag[0] = true 
			elsif char == ' ' && oflag[0] == true && oflag[1] == true
				r += '<'
				oflag = nil
			end
		}
		next if r == ""
		# add the string to the output file if it's nonempty / is not just a newline
		nocomments << r
	}
	return nocomments
end

# takes a file, opens it and strips out the white spaces, blank lines, etc.
def handleFile(f)
	file = File.open(f,'r')
	rem = stripWhiteSpace(file)
	# grab just the file name (not the full path) 
	fl = f.split('/')[-1][0...-3]
	# return a hash with the parsed lines of the file & the file name
	return {:lines => rem, :file => fl}
end

# takes the command as argument
def commandType(c)
	# this array of hashes looks weird, but its clear later why this is useful 
	arithmetic = [
		{:c => 'add',:s =>'+'},
		{:c => 'sub',:s => '-'},
		{:c => 'neg', :s => '-'},
		{:c => 'eq', :s => 'JEQ'},
		{:c => 'gt', :s => 'JGT'},
		{:c => 'lt', :s => 'JLT'},
		{:c => 'and', :s => '&'},
		{:c => 'or', :s => '|'},
		{:c => 'not', :s => '!'}
	]
	# the possible command types (other than arithmetic)
	ret = ['push', 'pop', 'label', 'goto', 'if', 'function', 'return', 'call']
	# select the ones that appear in the string
	r1 = ret.select{|x| c.include?(x)}
	# select the arithmetic commands that appear in the string & add them to the existing array
	r2 = arithmetic.select{|x| c.include?(x[:c])}
	if r1.length > 0 && r2.length > 0 then ret = c.index(r1[0]) < c.index(r2[0][:c]) ? r1 : r2
	else ret = r1.length > 0 ? r1 : r2 end
	# the size of our array should be 1 unless its a special case o.w. throw error
	if ret == ['goto','if'] then ret = ['goto-if'] end
	if ret.length == 1 then return ret else return -1 end 
end

# takes the command (c) and the command type (type) as args and returns an
# array of the command's arguments
def arg(c,type)
	# possible segments
	mac = ['argument','local','static','constant','this','that','pointer','temp']
	# remove the initial command piece from the command line 
	rem = c[type.length...c.length]
	# if its an arithmetic command just return it 
	if type.class == Hash then return c
	elsif type.include?('goto') then rem = rem.tr('<',''); return [rem,type.include?('if')]
	elsif rem.include?('<') then return rem.split('<')
	# if its a function or a call, grab its numeric piece (arg2) which specifies
	# nLocals or nArgs, then remove that piece -- the remaining piece is arg1
	elsif type == 'function' || type == 'call'
		r = rem.reverse
		g = ""
		for i in 0...rem.length do Float(r[i]) rescue break; g += r[i] end
		b = rem.split('').first(rem.length-i).join('')
		return [b,g]
	# if its a push or pop, grab the piece that specifies the sgmt (arg1) and then
	# remove, yielding the remaining arg (arg2)
	elsif type == 'push' || type == 'pop'
		t = mac.select{|x| rem.include?(x)}
		if t.length > 1 then return -1
		else return [t[0],rem.gsub(t[0],"")] end
	elsif type == 'label' then return [rem]
	else return rem end
end



