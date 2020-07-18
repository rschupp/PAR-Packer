#!perl

use strict;
use warnings;
use File::Basename;

sub is_system_lib { shift =~ m{^/usr/lib|^/System/Library/} };

sub find_files_to_embed
{
    my ($par, $libperl) = @_;

    my $dlls = otool($par); 

    # weed out system libs (but exclude the shared perl lib)
    foreach my $name (keys %$dlls)
    {
        my $path = $dlls->{$name};
        delete $dlls->{$name} if is_system_lib($path) && basename($path) !~ /perl/;
    }

    return $dlls;
}

# NOTE: "otool -L" is NOT recursive, i.e. it's the equivalent
# of "objdump -ax" or "readelf -d" on Linux, but NOT "ldd".
# So perhaps a recursive method like the one for objdump below is in order.
sub otool
{
    my ($file) = @_;

    my $out = qx(otool -L $file);
    die qq["otool -L $file" failed\n] unless $? == 0;

    return { map { basename($_) => $_ } $out =~ /^ \s+ (\S+) /gmx };
}

1;
