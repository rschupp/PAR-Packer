#!/usr/bin/perl -w

# Copyright (c) 2002 Mattia Barbon.
# Copyright (c) 2002 Audrey Tang.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Basename;
use Getopt::Long;
use PAR::Filter::PodStrip;

my $chunk_size = 0;
my $long_literal;
my $strip_pod;
my $name;

GetOptions(
    "c|chunk-size=i"    => \$chunk_size,
    "l|long-literal"    => \$long_literal,
    "s|strip_pod"       => \$strip_pod,
    "n|name=s"          => \$name,
) && @ARGV == 3
    or die "Usage: $0 [-c chunk_size][-l][-n name][-s] file.pl file.c c_variable\n";
my ($pl_file, $c_file, $c_var) = @ARGV;
$name = basename($pl_file) unless defined $name;

my $pl_text = do        # NOTE: scalar ref
{
    open my $in, "<", $pl_file or die "open input file '$pl_file': $!";
    binmode $in;
    local $/ = undef;
    my $slurp = <$in>;
    close $in;
    \$slurp;
};

PAR::Filter::PodStrip->new->apply($pl_text) if $strip_pod;

open my $out, ">", $c_file or die "open output file '$c_file': $!";
binmode $out;

#  make a c-array

print $out "const char * name_$c_var = \"$name\";\n";

if ($chunk_size) {
    my $len = length $$pl_text;
    my $chunk_count = int(( $len + $chunk_size - 1 ) / $chunk_size);
    print $out "unsigned long size_$c_var = $len;\n";

    for (my $i = 0; $i < $chunk_count; $i++) {
	print_chunk( substr($$pl_text, $i * $chunk_size, $chunk_size), "_$i" );
    }

    print $out "#define WRITE_$c_var(i)";
    for (my $i = 0; $i < $chunk_count; $i++) {
	print $out " write(i, ${c_var}_$i, (size_t)size_${c_var}_$i);";
    }
    print $out "\n";
}
else {
    print_chunk( $$pl_text, '' );
    print $out "#define WRITE_${c_var}(i) write(i, $c_var, (size_t)size_${c_var});\n";
}
close $out;

sub print_chunk {
    my $chunk = reverse($_[0]);
    my $suffix = $_[1];

    my $len = length $chunk;
    print $out "unsigned long size_${c_var}${suffix} = $len;\n";
    print $out "const char ${c_var}${suffix}[] = ";
    print $out $long_literal ? "\"" : "{";

    my $fmt = $long_literal ? "\\x%02x" : "0x%02x,";
    while ($len--) {
        printf $out $fmt, ord(chop($chunk));
        print $out $long_literal ? "\"\n\"" :"\n" unless $len % 16;
    }

    print $out $long_literal ? "\";\n" : "\n};\n";
}

# local variables:
# mode: cperl
# end:
