use strict;
use warnings;
# Used in myldr/Makefile.PL / myldr/Makefile.
# This script appends the uuencoded contents of $ARGV[0] to the file
# specified as $ARGV[1] as __DATA__ section. Any previous _DATA_ is replaced.
# section.
#
# copyright 2006-2009, Steffen Mueller

$/ = undef;

my $usage = <<HERE;
Usage: $0 FILE-TO-ENCODE FILE-TO-APPEND-TO
HERE

my $infile = shift @ARGV;
die $usage if not defined $infile or not -f $infile;

my $outfile = shift @ARGV;
die $usage if not defined $outfile or not -f $outfile;

open my $fh, '<', $outfile or die $!;
binmode $fh;
my $contents = <$fh>;
close $fh;
$contents =~ s/^__DATA__\r?\n.*\z//ms;

open my $ih, '<', $infile or die $!;
binmode $ih;
open $fh, '>', $outfile or die $!;
binmode $fh;
print $fh $contents;
print $fh "\n__DATA__\n";
print $fh pack 'u', <$ih>;
close $ih;
close $fh;
