#!/usr/bin/perl -w
# Copyright 2002, 2003, 2004, 2005, 2006 by Audrey Tang.
# Copyright (c) 2002 Mattia Barbon.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use Config;
use File::Spec;
use ExtUtils::Embed;
use DynaLoader;
use File::Basename;

xsinit(undef);

# used for searching libperls.
sub find_file {
    my $file = shift;

    my @paths = (
	    $Config{bin},
    	File::Spec->catdir($Config{'archlibexp'}, 'CORE'),
	    split(/\Q$Config{path_sep}\E/, $ENV{$Config{ldlibpthname}} || ''),
    	split(/ /, $Config{libpth}),
    );

    my $libperl;
    if ($libperl = DynaLoader::dl_findfile("-lperl")) {
        if (-l $libperl) {
            my $realpath = readlink($libperl);
            if (!File::Spec->file_name_is_absolute($realpath)) {
                $realpath = File::Spec->rel2abs(
                    File::Spec->catfile(
                        dirname($libperl) => $realpath
                    )
                );
            }
            $libperl = $realpath;
        }
        return $libperl if -e $libperl;
    }

    foreach my $path (@paths) {
	    $libperl = File::Spec->catfile($path, $file);
    	return $libperl if -e $libperl;
        
    	# for MinGW
	    $libperl = File::Spec->catfile($path, $1) if $file =~ /^lib(.+)/;
    	return $libperl if -e $libperl;
        
       	# for Cygwin
    	$libperl = File::Spec->catfile($path, $file.$Config{_a});
    	return $libperl if -e $libperl;
    }
}

my $debug = $ENV{DEBUG};
my $chunk_size = 30000;
my $perl = $^X;
my $exe = $Config{_exe};
my $link_exe = (($^O eq 'os2' and $Config{ldflags} =~ /-Zexe/) ? '' : $exe);
my $o = $Config{obj_ext};
my $gccversion = $Config{gccversion};
my $pccflags = ccopts();
my $pldflags = ldopts();
my $dynperl = $Config{useshrplib} && ($Config{useshrplib} ne 'false');

$dynperl = 1 if $pldflags =~ /\B-lperl\b/; # Gentoo lies to us!

my $cc = $Config{cc};
my $ld = $Config{ld} || (($^O eq 'MSWin32') ? 'link.exe' : $Config{cc});
$ld = $Config{cc} if ($^O =~ /^(?:dec_osf|aix)$/);

my $f2c = File::Spec->catfile('.', "file2c.pl");
my $par_pl = File::Spec->catfile('..', 'script', "par.pl");
my $par_exe = File::Spec->catfile('.', "par$exe");
my $par_exe_link = File::Spec->catfile('.', "par$link_exe");
my $static_exe = File::Spec->catfile('.', "static$exe");
my $static_exe_link = File::Spec->catfile('.', "static$link_exe");
my $parl_exe = File::Spec->catfile('..', 'script', "parl$exe");
my $parldyn_exe = File::Spec->catfile('..', 'script', "parldyn$exe");
my $strippedparl_mod = File::Spec->catfile(
    '..', 'blib', 'lib', 'PAR', 'StrippedPARL', 'Static.pm'
);
my $strippedparldyn_mod = File::Spec->catfile(
    '..', 'blib', 'lib', 'PAR', 'StrippedPARL', 'Dynamic.pm'
);
my $lib_path = join(' ', map qq(-I"$_"), @INC);

my( $out, $ccdebug, $lddebug, $warn, $rm, $mv, $res, $long_literal );

if( $cc =~ m/^cl\b/i ) {
    $out = '-out:';
    $ccdebug = $debug ? '-Zi -Zm1000 ' : '-Zm1000 ';
    $lddebug = $debug ? '-debug ' : '-release ';
    $warn = $debug ? '-W3' : '';
    $res = 'win32.obj';
    $long_literal = 0;
} elsif ($cc =~ m/^gcc\b/i or ($cc =~ m/^cc\b/i and $gccversion)) {
    $out = '--output ';
    $ccdebug = $debug ? '-g ' : '';
    $lddebug = ($debug or $^O eq 'darwin') ? '' : '-s ';
    $warn = $debug ? '-Wall -Wno-comments ' : '';
    $res = ($^O =~ /^(?:MSWin|cygwin)/) ? 'win32.coff' : '';
    $long_literal = 1;
} else {
    $out = '-o ';
    $ccdebug = '';
    $lddebug = '';
    $warn = '';
    $res = '';
    $long_literal = 0; # better safe than sorry
}


my  $cflags = "$ccdebug$warn$pccflags";
my $ldflags = "$lddebug$pldflags";
my $static_ldflags = $ldflags;

$static_ldflags =~ s/\s+-lperl\s+/ /g;

my $libperl;

if ($dynperl and $^O eq 'os2') {
    $libperl = OS2::DLLname();
}
elsif ($dynperl) {
    my $file = $Config{libperl};
    my $so = $Config{so} || 'so';
    $file = "libperl.$so" if $file eq 'libper'; # workaround Red Hat bug

    $file =~ s/\.(?!\d)[^.]*$/.$Config{so}/;

    $libperl = find_file($file);
    if (not -e $libperl) {
        $file =~ s/\.(?!\d)[^.]*$/.a/;
        $libperl = find_file($file);
    }

    # die "Can't find $file in (@paths) -- please contact the author!"
    # 	unless -e $libperl;
    undef $dynperl if !-e $libperl;
}

if (not $dynperl) {
    my $file = $Config{libperl};
    $file = 'libperl.a' if $file eq 'libper'; # same redhat bug? Just making sure...
    $libperl = find_file($file);
    $ldflags = $static_ldflags;
}

my $par = (($dynperl && $^O ne 'os2') ? $static_exe : $par_exe);
my $all = (
    $dynperl
    ? "$parl_exe $parldyn_exe strippedparl strippedparldyn"
    : "$parl_exe strippedparl"
);

$perl = Win32::GetShortPathName($perl)
    if $perl =~ / / and defined &Win32::GetShortPathName;


# Determine whether we can find a config.h. If yes, include it in
# usernamefrompwuid.h. If not, set I_PWD to undefined in that header.
# -- Steffen
my $configh = "$Config::Config{archlibexp}/CORE/config.h";
open PWOUT, '> usernamefrompwuid.h' or die "open 'usernamefrompwuid.h': $!";
if (not -f $configh) {
    print PWOUT "#undef I_PWD\n";
}
else {
    print PWOUT "#include \"$configh\"\n";
}
close PWOUT;


print "Writing Makefile for the par$exe program\n";

open OUT, "> Makefile" or die "open 'Makefile': $!";

$rm = $^O eq 'MSWin32' ? '$(PERL) -MExtUtils::Command -e rm_f' : 'rm -f';
$mv = $^O eq 'MSWin32' ? '$(PERL) -MExtUtils::Command -e mv' : 'mv';

# XXX - Commented out this chunk (rt.cpan #16075)
#       not sure what the condition was testing against - disabled for now.
# if (-e $par_exe and not -s $par_exe) {
#     print OUT "all ::\n\t$^X -e1\n";
# }
# else {
    print OUT << "EOT";
# AUTOGENERATED, DO NOT EDIT, RERUN Makefile.PL

RM=$rm
MV=$mv
PERL=$perl
LD=$ld
CC=$cc
CFLAGS=$cflags
LDFLAGS=$Config{ldflags}
PERL_LDFLAGS=$ldflags
STATIC_LDFLAGS=$static_ldflags
NOOP=\$(PERL) -e1

OBJECTS=main$o my_par_pl$o $res

.c$o:
	\$(CC) -c \$(CFLAGS) \$<

all: $all

main.$o: main.c

main.c: perlxsi.c mktmpdir.c internals.c

mktmpdir.c: mktmpdir.h

mktmpdir.h: utils.c sha1.c

clean:
	-\$(RM) my_*.c
	-\$(RM) main$o my_par_pl$o static$o
	-\$(RM) sha1$o sha1.c
	-\$(RM) *.opt *.pdb perlxsi.c
	-\$(RM) usernamefrompwuid.h
	\$(MV) Makefile Makefile.old

realclean: clean
	-\$(RM) $par_exe
	-\$(RM) $parl_exe
	-\$(RM) $static_exe
	-\$(RM) Makefile Makefile.old

distclean: clean
	-\$(RM) $par_exe
	-\$(RM) $parl_exe
	-\$(RM) $static_exe
	-\$(RM) Makefile Makefile.old

$par_exe: sha1$o \$(OBJECTS) my_par_pl$o
	\$(LD) \$(OBJECTS) \$(PERL_LDFLAGS) $out$par_exe_link

my_par_pl.c: $par_pl
	\$(PERL) $f2c $par_pl \$@ load_me_2 $long_literal

$parl_exe: $par
	$par $lib_path -I../myldr/.. -I../blib/lib -q -B -O\$@

disttest:
	-\$(NOOP)

test:
	-\$(NOOP)

.DEFAULT:
	-\$(NOOP)

.SUFFIXES: $o

sha1.c: sha1.c.PL
	\$(PERL) sha1.c.PL sha1.c

EOT

    print OUT << "EOT" if $dynperl;

$parldyn_exe: $par_exe
	$par_exe -I../myldr/.. -I../blib/lib $lib_path -q -B -O\$@

static$o: my_perl.c my_par.c mktmpdir.c

$static_exe: sha1$o static$o
	\$(LD) static$o \$(STATIC_LDFLAGS) $res $out$static_exe_link
	\$(PERL) parlsig.pl $static_exe $par_exe $dynperl $chunk_size

my_perl.c:
	\$(PERL) $f2c $libperl \$@ load_me_0 $long_literal $chunk_size

my_par.c: $par_exe
	\$(PERL) $f2c $par_exe \$@ load_me_1 $long_literal $chunk_size

strippedparl: $par
	\$(PERL) -e "chmod(oct('0600'), '$strippedparl_mod');"
	\$(PERL) encode_append.pl $par $strippedparl_mod
	\$(PERL) -e "chmod(oct('0444'), '$strippedparl_mod');"

strippedparldyn: $par_exe
	\$(PERL) -e "chmod(oct('0600'), '$strippedparldyn_mod');"
	\$(PERL) encode_append.pl $par_exe $strippedparldyn_mod
	\$(PERL) -e "chmod(oct('0444'), '$strippedparldyn_mod');"

EOT
# }

# local variables:
# mode: cperl
# end:
