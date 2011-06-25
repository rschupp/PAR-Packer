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
use IO::Compress::Gzip qw(gzip $GzipError);

my $chunk_size = 0;
my $strip_pod = 0;
my $compress = 0;
my $name;

GetOptions(
    "c|chunk-size=i"    => \$chunk_size,
    "s|strip"           => \$strip_pod,
    "z|compress"        => \$compress,
    "n|name=s"          => \$name)
    && @ARGV == 3
        or die "Usage: $0 [-c CHUNK][-n NAME][-s][-z] file.pl file.c c_variable\n";
my ($pl_file, $c_file, $c_var) = @ARGV;
$name = basename($pl_file) unless defined $name;

my $pl_text = do           # a scalar reference
{
    open my $in, "<", $pl_file or die "open input file '$pl_file': $!";
    binmode $in;
    local $/ = undef;
    my $slurp = <$in>;
    close $in;
    \$slurp;
};

PAR::Filter::PodStrip->new->apply($pl_text) if $strip_pod;

if ($compress)
{
    my $gzipped;
    my $status = gzip($pl_text, \$gzipped)
        or die "gzip failed: $GzipError\n";
    $pl_text = \$gzipped;
}

open my $out, ">", $c_file or die "open output file '$c_file': $!";
binmode $out;

my $len = length $$pl_text;

print $out <<"...";
#define name_${c_var} "$name"
#define is_compressed_${c_var} $compress
...

if ($chunk_size) 
{
    my $chunk_count = int(( $len + $chunk_size - 1 ) / $chunk_size);

    for (my $i = 0; $i < $chunk_count; $i++) {
	print_chunk( substr($$pl_text, $i * $chunk_size, $chunk_size), "_$i" );
    }

    print $out <<"...";
#define size_${c_var} $len
static my_chunk chunks_${c_var}[] = {
...
    for (my $i = 0; $i < $chunk_count; $i++) {
        print $out " { size_${c_var}_${i}, chunk_${c_var}_${i} },\n";
    }
    print $out " { 0, NULL }\n", "};\n";
}
else
{
    # add a NUL byte so that chunk_${c_var} may be used as C string
    $$pl_text .= "\0";
    print_chunk( $$pl_text, "" );    
}

close $out;

exit 0;


sub print_chunk 
{
    my ($chunk, $suffix) = @_;

    my $len = length($chunk);
    print $out <<"...";
#define size_${c_var}${suffix} $len
static unsigned char chunk_${c_var}${suffix}[] = {
...

    for (my $i = 0; $i < $len; $i++) {
        printf $out "0x%02x,", ord(substr($chunk, $i, 1));
        print $out "\n" if $i % 16 == 15;
    }

    print $out "};\n";
}

# local variables:
# mode: cperl
# end:
