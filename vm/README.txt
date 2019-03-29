The most popular implementation of Ruby is MRI which is an interpreted language. There are other implementations which are compiled. The user never has to compile the code himself/herself, so it shouldn't matter which implementation you're running. Simply call:

$ ruby filename.rb

in order to execute (and potentially compile) a Ruby file. At the risk of stating the obvious, the dollar sign is not part of the command, it signifies BASH input. My vm.rb file ingests the path to the input .vm file or directory. For example: 

$ ruby vm.rb filename.vm

Or 

$ruby vm.rb directory

will produce a file called filename.asm in the same directory as filename.vm (or directory). filename.vm is a file consisting of vm instructions and directory is a directory consisting of '.vm' files. Note if there are non-'.vm' files in the directory they will be ignored.

$ ruby vm.rb

will output an error related to the fact that no file or directory has been specified 

$ ruby vm.rb ~/abc/filename.vm 

will output an error if this file is not found in this location

$ ruby vm.rb filename.txt 

will output an error related to the fact that the file specified has a .txt extension instead of a .asm extension. 

If the virtual machine successfully parses a file with n lines, a message will be printed at the command line indicating success. Otherwise, the assembler will print an error message indicated the line number and the type of error. 

This virtual machine has been tested on FibonacciElement, NestedCalled, SimpleFunction, StaticsTest, BasicLoop, and FibonacciSeries. The virtual machine generates assembly instructions that output results consistent with the comparison file. Please note that this assignment takes advantage of logic previously used in Project 0 and in Project 6 to strip white spaces and comments from a file. In addition, this assignment relies on pieces of logic from Project 0 and Project 6 used to load files and output text to a file.