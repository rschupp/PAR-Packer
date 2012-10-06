use strict;
use warnings;

use PAR::Filter::PodStrip;

my ($var) = @ARGV;

my $slurp;
{
    local $/ = undef;
    $slurp = <STDIN>;
};

PAR::Filter::PodStrip->new->apply(\$slurp);

print "const char *$var =\n";
foreach (split(/\n/, $slurp))
{
    s/(["\\])/\\$1/g;           # escape quotes and backslashes
    print qq["$_\\n"\n];
}
print ";\n"
