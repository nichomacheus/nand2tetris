The most popular implementation of Ruby is MRI which is an interpretted langauge. There are other implementations which are compiled. The user never has to compile the code himself/herself, so it shouldn't matter which implementation you're running. Simply call:

$ ruby filename.rb

in order to execute (and potentially compile) a Ruby file. At the risk of stating the obvious, the dollar sign is not part of the command, it signifies BASH input. My assembler.rb file injests the path to the input .asm file. For example: 

$ ruby assembler.rb filename.asm

will produce a file called filename.hack in the same directory as filename.asm. filename.hack is a file consisting of binary machine instructions.

$ ruby assembler.rb

will output an error related to the fact that no file has been specified 

$ ruby assembler.rb ~/abc/filename.asm 

will output an error if this file is not found in this location

$ ruby assembler.rb filename.txt 

will output an error related to the fact that the file specified has a .txt extension instead of a .asm extension. 

If the assembler successfully parses a file with n lines, a message will be printed at the command line indicating success. Otherwise, the assembler will print an error message indicated the line number and the type of error. 


This assembler has been tested on Pong.asm, Rect.asm, Add.asm, Max.asm, Fill.asm, and Mult.asm. The assembler generates the same binary instructions as the built-in assembler on these examples. Please note that this assignment takes advantage of logic previously used in Project 0 to strip white spaces and comments from a file. 