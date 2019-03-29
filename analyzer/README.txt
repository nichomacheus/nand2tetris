The most popular implementation of Ruby is MRI which is an interpreted language. There are other implementations which are compiled. The user never has to compile the code himself/herself, so it shouldn't matter which implementation you're running. Simply call:

$ ruby filename.rb

in order to execute (and potentially compile) a Ruby file. At the risk of stating the obvious, the dollar sign is not part of the command, it signifies BASH input. My analyzer.rb file ingests the path to the input .jack file or directory. For example: 

$ ruby analyzer.rb filename.jack

Or 

$ruby analyzer.rb directory

will produce a file called filename.xml in the current directory. filename.jack is a Jack file and directory is a directory consisting of '.jack' files. Note if there are non-'.jack' files in the directory they will be ignored.

$ ruby analyzer.rb

will output an error related to the fact that no file or directory has been specified 

$ ruby analyzer.rb ~/abc/filename.jack 

will output an error if this file is not found in this location

$ ruby analyzer.rb filename.txt 

will output an error related to the fact that the file specified has a .txt extension instead of a .jack extension. 

If the analyzer successfully parses a file the command will return successfully. Otherwise, the analyzer will print an error message indicated the line number and the type of error. 

The tokenizer and analyzer have been tested on all of the provided tests including Square, ExpressionLessSquare, and ArrayTest and both function properly. This assignment relies on pieces of logic from Project 0 and Project 6 used to load files and output text to a file.