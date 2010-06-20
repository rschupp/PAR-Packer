#!/usr/bin/perl -w
# Copyright 2002-2009 by Audrey Tang.
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
$ld = $Config{cc} if ($^O =~ /^(?:dec_osf|aix|hpux)$/);

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

my( $out, $ccdebug, $lddebug, $warn, $rm, $mv, $res, $long_literal, $mt_cmd );

if( $cc =~ m/^cl\b/i ) {
    $out = '-out:';
    $ccdebug = $debug ? '-Zi -Zm1000 ' : '-Zm1000 ';
    $lddebug = $debug ? '-debug ' : '-release ';
    $warn = $debug ? '-W3' : '';
    $res = $Config{ivsize} == 4 ? 'win32.obj' : '';
    $long_literal = 0;
    # Embed the manifest file for VC 2005 (aka VC8) or higher, but not for the
    # 64-bit Platform SDK compiler
    if( $Config{ivsize} == 4 and $Config{ccversion} =~ /^(\d+)/ and $1 >= 14 ) {
        $mt_cmd = 'mt -nologo -manifest $@.manifest -outputresource:$@;1';
    } else {
        $mt_cmd = '-$(NOOP)';
    }
} elsif ($cc =~ m/^gcc\b/i or ($cc =~ m/^cc\b/i and $gccversion)) {
    $out = '-o ';
    $ccdebug = $debug ? '-g ' : '';
    $lddebug = ($debug or $^O eq 'darwin') ? '' : '-s ';
    $warn = $debug ? '-Wall -Wno-comments ' : '';
    $res = ($^O =~ /^(?:MSWin|cygwin)/) ? 'win32.coff' : '';
    $long_literal = 1;
    $mt_cmd = '-$(NOOP)';
} else {
    $out = '-o ';
    $ccdebug = '';
    $lddebug = '';
    $warn = '';
    $res = '';
    $long_literal = 0; # better safe than sorry
    $mt_cmd = '-$(NOOP)';
}


my $perl58lib = "";
if($ENV{ACTIVEPERL_MINGW} and $Config{cf_email}=~/ActiveState.com/i){
    chomp $pldflags;
    $perl58lib = "-l$Config{libperl}";
    $perl58lib =~ s/\.lib$//;
}
my $cflags = "$ccdebug$warn$pccflags";
my $optimize = $Config{optimize};
my $ldflags = "$lddebug$pldflags $perl58lib";
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
    $file =~ s/^lib// if $^O eq "MSWin32";

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


# If on Windows and Perl was built with GCC 4.x, then libperl*.dll
# may depend on some libgcc*.dll (Strawberry Perl 5.12 is an example).
# This libgcc*.dll has to be included into with any packed executbale 
# in the same way as libperl*.dll itself, otherwise a packed executable
# won't run when libgcc*.dll isn't installed.
my $libgcc;
if ($dynperl and $^O eq 'MSWin32'
    and defined $Config{gccversion}     # gcc version 4.x or above was used
    and $Config{gccversion} =~ m{\A(\d+)}ms && $1 >= 4) {
    # look for a libgcc_*.dll in the same directory
    # as the perl executable itself
    ($libgcc) = glob(File::Spec->catfile(File::Basename::dirname($^X),
                                         "libgcc_*.$Config{so}"));
}
$libgcc ||= "";

my $my_stuff = "my_par.c my_libperl.c";
if ($libgcc) {
    $cflags .= " -DLOAD_MY_LIBGCC";
    $my_stuff .= " my_libgcc.c";
}


my $all = "$parl_exe strippedparl";
$all .= " $parldyn_exe strippedparldyn" if $dynperl;

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
CFLAGS=$cflags -DPARL_EXE=\\"parl$exe\\"
OPTIMIZE=$optimize
LDFLAGS=$Config{ldflags}
PERL_LDFLAGS=$ldflags
STATIC_LDFLAGS=$static_ldflags
NOOP=\$(PERL) -e1

OBJECTS=main$o my_par_pl$o $res
MKTMP_STUFF=mktmpdir.c mktmpdir.h utils.c sha1.c

.c$o:
	\$(CC) -c \$(CFLAGS) \$(OPTIMIZE) \$<

all: $all

main$o: main.c perlxsi.c internals.c \$(MKTMP_STUFF)

clean:
	-\$(RM) my_*.c
	-\$(RM) main$o my_par_pl$o static$o
	-\$(RM) sha1.c
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

$par_exe: \$(OBJECTS) my_par_pl$o
	\$(LD) \$(OBJECTS) \$(PERL_LDFLAGS) $out$par_exe_link
	$mt_cmd

my_par_pl.c: $par_pl
	\$(PERL) $f2c $par_pl \$@ load_my_par_pl $long_literal

$parl_exe: $par
	\$(PERL) run_with_inc.pl $par -I../blib/lib -q -B -O\$@

strippedparl: $par
	\$(PERL) -e "chmod(oct('0600'), '$strippedparl_mod');"
	\$(PERL) encode_append.pl $par $strippedparl_mod
	\$(PERL) -e "chmod(oct('0444'), '$strippedparl_mod');"

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
	\$(PERL) run_with_inc.pl $par_exe -I../blib/lib -q -B -O\$@

static$o: \$(MKTMP_STUFF) $my_stuff

$static_exe: static$o
	\$(LD) static$o \$(STATIC_LDFLAGS) $res $out$static_exe_link
	$mt_cmd
	\$(PERL) parlsig.pl $static_exe $par_exe $dynperl $chunk_size

my_par.c: $par_exe
	\$(PERL) $f2c $par_exe \$@ load_my_par $long_literal $chunk_size

my_libperl.c:
	\$(PERL) $f2c $libperl \$@ load_my_libperl $long_literal $chunk_size

my_libgcc.c:
	\$(PERL) $f2c $libgcc \$@ load_my_libgcc $long_literal $chunk_size

strippedparldyn: $par_exe
	\$(PERL) -e "chmod(oct('0600'), '$strippedparldyn_mod');"
	\$(PERL) encode_append.pl $par_exe $strippedparldyn_mod
	\$(PERL) -e "chmod(oct('0444'), '$strippedparldyn_mod');"

EOT
# }

# local variables:
# mode: cperl
# end:
