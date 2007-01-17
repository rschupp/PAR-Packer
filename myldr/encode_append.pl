use strict;
use warnings;
# Used in myldr/Makefile.PL / myldr/Makefile.
# This script appends the uuencoded contents of $ARGV[0] to the file
# specified as $ARGV[1] if the file in $ARGV[1] ends with an empty __DATA__
# section.
#
# 2006, Steffen Mueller

$/ = undef;

my $usage = <<HERE;
Usage: $0 FILE-TO-ENCODE FILE-TO-APPEND-TO
HERE

my $infile = shift @ARGV;
die $usage if not defined $infile or not -f $infile;

my $outfile = shift @ARGV;
die $usage if not defined $outfile or not -f $outfile;

open my $fh, '<', $outfile or die $!;
my $contents = <$fh>;
close $fh;
if (not defined $contents or $contents !~ /__DATA__\s*$/s) {
    warn "Output file '$outfile' does not have an empty __DATA__ section. Not appending encoded data from '$infile'. This is NOT a fatal error!";
    exit();
}

open my $ih, '<', $infile or die $!;
binmode $ih;
open $fh, '>>', $outfile or die $!;
binmode $fh;
print $fh pack 'u', <$ih>;
close $ih;
close $fh;
