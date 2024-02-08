package XSFoo;

use 5.008009;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('XSFoo', $VERSION);

1;
