#!perl
# add -I options corresponding to @INC after the first element of @ARGV,
# then execute it
splice @ARGV, 1, 0, map { "-I$_" } @INC; 
exit(system(@ARGV) == 0 ? 0 : 1);
