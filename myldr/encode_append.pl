#!perl

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
Usage: $0 IN-FILE FILE-TO-ENCODE OUT-FILE
HERE

my $infile = shift @ARGV;
die $usage if not defined $infile or not -f $infile;

my $encfile = shift @ARGV;
die $usage if not defined $encfile or not -f $encfile;

my $outfile = shift @ARGV;
die $usage if not defined $outfile;

open my $in, '<', $infile or die $!;
binmode $in;
my $contents = <$in>;
close $in;

$contents =~ s/^__DATA__\r?\n.*\z//ms;

# cf. Config.pm
$contents .= sprintf <<'...', ($^V) x 2;
$^V eq %vd 
    or die sprintf("Perl (%%s) version (%%vd) doesn't match the version (%vd) ".
                   "that PAR::Packer was built with; please rebuild PAR::Packer", 
                   $^X, $^V);

1;
...


open my $enc, '<', $encfile or die $!;
binmode $enc;

unlink $outfile;
open my $out, '>', $outfile or die $!;
binmode $out;
print $out $contents;
print $out "\n__DATA__\n";
print $out pack 'u', <$enc>;
close $out;

close $enc;
