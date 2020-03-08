#!perl

use strict;
use warnings;

use blib;               # PAR::Filter::Podstrip might not be installed yet
use PAR::Filter::PodStrip;

my ($var) = @ARGV;

my $slurp = do { local $/ = undef; <STDIN> };

PAR::Filter::PodStrip->apply(\$slurp, '');

print "const char *$var =\n";
foreach (split(/\n/, $slurp))
{
    # Note: We've already podstripped stdin (i.e. par.pl), but
    # the generated C string will be passed through argc to our
    # custom Perl interpreter. Some legacy OS platforms have really
    # small _POSIX_ARG_MAX values, hence squeeze some more bytes from it. 
    s/^\s*|\s*$//g;             # strip leading and trailing whitespace
    next if /^#|^$/;            # skip comment (nad #line) and empty lines

    s/(["\\])/\\$1/g;           # escape quotes and backslashes
    print qq["$_\\n"\n];
}
print ";\n"
