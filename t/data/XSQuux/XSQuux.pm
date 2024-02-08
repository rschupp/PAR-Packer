package XSQuux;

use strict;
use warnings;

our $VERSION = '0.01';

use Exporter;
require DynaLoader;
our @ISA = qw(DynaLoader Exporter);
sub dl_load_flags {0x01}

__PACKAGE__->bootstrap($VERSION);

1;
