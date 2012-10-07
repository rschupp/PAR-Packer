use strict;
use warnings;

use blib;               # PAR::Filter::Podstrip might not be installed yet
use PAR::Filter::PodStrip;

my ($var) = @ARGV;

my $slurp = do { local $/ = undef; <STDIN> };

PAR::Filter::PodStrip->new->apply(\$slurp);

print "const char *$var =\n";
foreach (split(/\n/, $slurp))
{
    s/(["\\])/\\$1/g;           # escape quotes and backslashes
    print qq["$_\\n"\n];
}
print ";\n"
