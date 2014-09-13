#!perl

# Copyright (c) 2002 Mattia Barbon.
# Copyright (c) 2002 Audrey Tang.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Basename;
use Getopt::Long;
use IO::Compress::Gzip qw(gzip $GzipError);

my $chunk_size = 30000;
my $compress = 0;
my $name;

GetOptions(
    "c|chunk-size=i"    => \$chunk_size,
    "z|compress"        => \$compress)
    && @ARGV > 0
        or die "Usage: $0 [-c CHUNK][-z] bin_file... > file.c\n";

binmode STDOUT;

my $i = 0;
my @embedded_files = map { process($i++, $_) } @ARGV;

print "embedded_file_t embedded_files[] = {\n";
print "  { \"$_->{name}\", $_->{size}, $_->{chunks} },\n" foreach @embedded_files;
print "  { NULL, 0, NULL }\n};";
           
exit 0;


sub process
{
    my ($i, $path) = @_;

    my $bin = do           # a scalar reference
    {
        open my $in, "<", $path or die "open input file '$path': $!";
        binmode $in;
        local $/ = undef;
        my $slurp = <$in>;
        close $in;
        \$slurp;
    };


    if ($compress)
    {
        my $gzipped;
        my $status = gzip($bin, \$gzipped)
            or die "gzip failed: $GzipError\n";
        $bin = \$gzipped;
    }

    my $len = length $$bin;
    my $chunk_count = int(( $len + $chunk_size - 1 ) / $chunk_size);

    my @chunks;
    for (my $j = 0; $j < $chunk_count; $j++) {
        push @chunks, { 
               buf => "chunk_${i}_${j}",
               len => print_chunk( substr($$bin, $j * $chunk_size, $chunk_size), "chunk_${i}_${j}" ),
        };
    } 

    print "static chunk_t chunks_${i}[] = {\n";
    print "  { $_->{len}, $_->{buf} },\n" foreach @chunks;
    print "  { 0, NULL } };\n\n";

    return 
    {
        name    => basename($path),
        size    => -s $path,
        chunks  => "chunks_${i}",
    };
}


sub print_chunk 
{
    my ($chunk, $name) = @_;

    my $len = length($chunk);
    print "static unsigned char ${name}[] = {\n";
    for (my $i = 0; $i < $len; $i++) {
        printf "0x%02x,", ord(substr($chunk, $i, 1));
        print "\n" if $i % 16 == 15;
    }
    print "};\n";
    return $len;
}

# local variables:
# mode: cperl
# end:
