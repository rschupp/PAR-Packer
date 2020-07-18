#!perl

use strict;
use warnings;

sub is_system_lib;

sub find_files_to_embed
{
    my ($par, $libperl) = @_;

    if ($^O =~ /cygwin/i)
    {
        chomp(my $system_root = qx( cygpath --unix '$ENV{SYSTEMROOT}' ));
        print STDERR "### SystemRoot (as Unix path) = $system_root\n";
        *is_system_lib = sub { shift =~ m{^/usr/bin/(?!cygcrypt\b)|^\Q$system_root\E/}i }; 
        # NOTE: cygcrypt-0.dll is not (anymore) in the set of default Cygwin packages
    }
    else
    {
        *is_system_lib = sub { shift =~ m{^(?:/usr)?/lib(?:32|64)?/} };
    }

    my $dlls = ldd($par); 

    # weed out system libs (but exclude the shared perl lib)
    foreach my $name (keys %$dlls)
    {
        delete $dlls->{$name} if is_system_lib($dlls->{$name}) && $name !~ /perl/;
    }

    return $dlls;
}

sub ldd
{
    my ($file) = @_;

    my $out = qx(ldd $file);
    die qq["ldd $file" failed\n] unless $? == 0;

    # NOTE: On older Linux/glibc (e.g. seen on Linux 3.2.0/glibc 2.13)
    # ldd prints a line like
    #    linux-vdso.so.1 =>  (0x00007fffd2ff2000)
    # (without a pathname between "=>" and the address)
    # while newer versions omit "=>" in this case.
    my %dlls = $out =~ /^ \s* (\S+) \s* => \s* ( \/ \S+ ) /gmx;

    foreach my $name (keys %dlls)
    {
        my $path = $dlls{$name};
        unless (-e $path)
        {
            warn qq[# ldd reported strange path: $path\n];
            delete $dlls{$name};
            next;
        }
    }

    return \%dlls;
}

1;
