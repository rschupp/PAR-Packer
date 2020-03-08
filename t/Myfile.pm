package Myfile;

use strict;
use warnings;
use Cwd;

sub from_caller  { Cwd::realpath(_from_caller()) }
sub _from_caller { (caller)[1] }
sub from_file    { Cwd::realpath(__FILE__) }

1;
