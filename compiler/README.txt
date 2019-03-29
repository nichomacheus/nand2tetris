The most popular implementation of Ruby is MRI which is an interpreted language. There are other implementations which are compiled. The user never has to compile the code himself/herself, so it shouldn't matter which implementation you're running. Simply call:

$ ruby filename.rb

in order to execute (and potentially compile) a Ruby file. At the risk of stating the obvious, the dollar sign is not part of the command, it signifies BASH input. My compiler.rb file ingests the path to the input .jack file or directory. For example: 

$ ruby compiler.rb filename.jack

Or 

$ruby compiler.rb directory

will produce a file called filename.vm in the same directory as filename.jack (or directory). filename.jack is a Jack file consisting and directory is a directory consisting of Jack files. Note if there are non-'.jack' files in the directory they will be ignored.

$ ruby compiler.rb

will output an error related to the fact that no file or directory has been specified 

$ ruby compiler.rb ~/abc/filename.jack 

will output an error if this file is not found in this location

$ ruby compiler.rb filename.txt 

will output an error related to the fact that the file specified has a .txt extension instead of a .jack extension. 

If the compiler successfully parses a file with n lines, a message will be printed at the command line indicating success. Otherwise, the analyzer will print an error message indicated the line number and the type of error. 

The compiler has been tested on the Jack programs Average, ComplexArrays, ConvertToBin, Pong, Seven, and Square. The compiler produces '.vm' files that are identical to those produced by the JackCompiler. Please note that this assignment takes advantage of logic used in projects 0, 6, and 10. 