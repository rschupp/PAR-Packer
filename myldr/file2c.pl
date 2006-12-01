#!/usr/bin/perl -w

# Copyright (c) 2002 Mattia Barbon.
# Copyright (c) 2002 Audrey Tang.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Basename;
use PAR::Filter::PodStrip;

my $give_help = 0;
my $pl_file = shift;
my $c_file = shift;
my $c_var = shift;
my $long_literal = shift;
my $chunk_size = shift;

$give_help ||= ( !defined $pl_file or
                !defined $c_file or
                !defined $c_var );
$pl_file ||= '';
$c_file ||= '';
$give_help ||= !-e $pl_file;
if( $give_help ) {
  print <<EOT;
Usage: $0 file.pl file.c c_variable
EOT

  exit 1;
}

open IN, "< $pl_file" or die "open '$pl_file': $!";
open OUT, "> $c_file" or die "open '$c_file': $!";
binmode IN; binmode OUT;

# read perl file
undef $/;
my $pl_text = <IN>;
close IN;

PAR::Filter::PodStrip->new->apply(\$pl_text)
    if -e $pl_file and $pl_file =~ /\.p[lm]/i;

#  make a c-array

print OUT "const char * name_$c_var = \"" . basename($pl_file) . "\";\n";

if (!$chunk_size) {
    print_chunk($pl_text, '');
    print OUT "#define WRITE_$c_var(i) write(i, $c_var, (size_t)size_$c_var);\n";
}
else {
    my $chunk_count = int(length($pl_text) / $chunk_size) + 1;
    print OUT "unsigned long size_$c_var = " . length($pl_text) . ";\n";

    for (1 .. $chunk_count) {
	print_chunk( substr($pl_text, ($_ - 1) * $chunk_size, $chunk_size), "_$_" );
    }

    print OUT "#define WRITE_$c_var(i)";
    for (1 .. $chunk_count) {
	print OUT " write(i, ${c_var}_$_, (size_t)size_${c_var}_$_);";
    }
    print OUT "\n";
}
close OUT;

sub print_chunk {
    my $text = reverse($_[0]);
    my $suffix = $_[1];

    print OUT "unsigned long size_$c_var$suffix = " . length($text) . ";\n";
    print OUT "const char $c_var$suffix\[" . (length($text) + 1) . "] = ";
    print OUT $long_literal ? '"' : '{';

    my $i;
    for (1 .. length($text)) {
	if ($long_literal) {
	    print OUT sprintf '\%03o', ord(chop($text));
	}
	else {
	    print OUT sprintf "'\\%03o',", ord(chop($text));
	    print OUT "\n" unless $i++ % 16;
	}
    }

    print OUT $long_literal ? "\";\n" : "0\n};\n";
}

# local variables:
# mode: cperl
# end:
