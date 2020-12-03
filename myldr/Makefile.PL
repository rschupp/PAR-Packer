#!perl
# Copyright 2002-2009 by Audrey Tang.
# Copyright (c) 2002 Mattia Barbon.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
use Config;
use File::Spec::Functions ':ALL';
use ExtUtils::Embed;
use ExtUtils::MakeMaker;
use DynaLoader;
use File::Basename;

xsinit(undef);

# used for searching libperls.
sub find_file {
    my $file = shift;

    my @paths = (
	$Config{bin},
    	catdir($Config{'archlibexp'}, 'CORE'),
	split(/\Q$Config{path_sep}\E/, $ENV{$Config{ldlibpthname}} || ''),
    	split(/ /, $Config{libpth}),
    );

    my $libperl;
    if ($libperl = DynaLoader::dl_findfile("-lperl")) {
        if (-l $libperl) {
            my $realpath = readlink($libperl);
            if (!file_name_is_absolute($realpath)) {
                $realpath = rel2abs(catfile(dirname($libperl), $realpath));
            }
            $libperl = $realpath;
        }
        return $libperl if -e $libperl;
    }

    foreach my $path (@paths) {
	    $libperl = catfile($path, $file);
    	return $libperl if -e $libperl;
        
    	# for MinGW
	    $libperl = catfile($path, $1) if $file =~ /^lib(.+)/;
    	return $libperl if -e $libperl;
        
       	# for Cygwin
    	$libperl = catfile($path, $file.$Config{_a});
    	return $libperl if -e $libperl;
    }
}

my $debug = $ENV{DEBUG};
my $chunk_size = 32768;
my $exe = $Config{_exe};
my $link_exe = (($^O eq 'os2' and $Config{ldflags} =~ /-Zexe/) ? '' : $exe);
my $o = $Config{obj_ext};
my $gccversion = $Config{gccversion};
# NOTE: on some platforms, ccopts or ldopts may contain newlines
chomp( my $pccflags = ccopts() );
chomp( my $pldflags = ldopts() );
my $dynperl = $Config{useshrplib} && ($Config{useshrplib} ne 'false');

$dynperl = 1 if $pldflags =~ /\B-lperl\b/; # Gentoo lies to us!

my $cc = $Config{cc};
my $ld = $Config{ld} || (($^O eq 'MSWin32') ? 'link.exe' : $Config{cc});
$ld = $Config{cc} if ($^O =~ /^(?:dec_osf|aix|hpux)$/);

my $par_pl = catfile('..', 'script', "par.pl");
my $par_exe = catfile('.', "par$exe");
my $par_exe_link = catfile('.', "par$link_exe");
my $boot_exe = catfile('.', "boot$exe");
my $boot_exe_link = catfile('.', "boot$link_exe");
my $parl_exe = "parl$exe";
my $parldyn_exe = "parldyn$exe";

my( $out, $ccdebug, $lddebug, $warn, $rm, $mv, $mt_cmd );

my $res = '';
my $res_section = '';
my $boot_ldflags = '';

if( $cc =~ m/^cl\b/i ) {
    $out = '-out:';
    $ccdebug = $debug ? '-Zi -Zm1000 ' : '-Zm1000 ';
    $lddebug = $debug ? '-debug ' : '-release ';
    $warn = $debug ? '-W3' : '';
    my $machinearch = $Config{ptrsize} == 8 ? 'AMD64' : 'X86';
    $res = 'ppresource.obj';
    $res_section = <<"...";
$res: winres\\pp.rc winres\\pp.manifest
	rc winres\\pp.rc
	cvtres /NOLOGO /MACHINE:$machinearch /OUT:$res winres\\pp.res
...

    # Embed the manifest file for VC 2005 (aka VC8) or higher, but not for the
    # 64-bit Platform SDK compiler.
    if( $Config{ptrsize} == 4 and $Config{ccversion} =~ /^(\d+)/ and $1 >= 14 ) {
        $mt_cmd = 'if exist $@.manifest mt -nologo -manifest $@.manifest -outputresource:$@;1';
    } else {
        $mt_cmd = '-$(NOOP)';
    }
} elsif ($cc =~ m/\bgcc\b/i or ($cc =~ m/\bcc\b/i and $gccversion)) {
    $out = '-o ';
    $ccdebug = $debug ? '-g ' : '';
    $lddebug = ($debug or $^O eq 'darwin') ? '' : '-s ';
    $warn = $debug ? '-Wall -Wno-comments ' : '';
    if ( $^O =~ /^(?:MSWin|cygwin)/ ) {
        my $target = $Config{ptrsize} == 8 ? 'pe-x86-64' : 'pe-i386';
        $res = 'ppresource.coff';
        # Note: On cygwin the command below will be processed by the
        # cygwin shell, so backslashes in pathnames might be a problem.
        # Instead use forward slashes which work on Windows as well.
        $res_section = <<"...";
$res: winres/pp.rc winres/pp.manifest
	windres -i winres/pp.rc -o $res --input-format=rc --output-format=coff --target=$target
...
    }
    $mt_cmd = '-$(NOOP)';
    $boot_ldflags .= ' -static-libgcc' if $^O eq 'MSWin32';
} else {
    $out = '-o ';
    $ccdebug = '';
    $lddebug = '';
    $warn = '';
    $mt_cmd = '-$(NOOP)';
}


my $perl58lib = "";
if($ENV{ACTIVEPERL_MINGW} and $Config{cf_email}=~/ActiveState.com/i){
    $perl58lib = "-l$Config{libperl}";
    $perl58lib =~ s/\.lib$//;
}
my $cflags = "$ccdebug$warn$pccflags";
my $optimize = $Config{optimize};
my $ldflags = "$lddebug$pldflags $perl58lib";
my $static_ldflags = $ldflags;

my $libperl;

if ($dynperl) {
    if ($^O eq 'os2') {
        $libperl = OS2::DLLname();
    }
    else {
        my $file = $Config{libperl};
        my $so = $Config{so} || 'so';
        $file = "libperl.$so" if $file eq 'libper'; # workaround Red Hat bug

        $file =~ s/\.(?!\d)[^.]*$/.$Config{so}/;
        $file =~ s/^lib// if $^O eq 'MSWin32';

        $libperl = find_file($file);
        if (not -e $libperl) {
            $file =~ s/\.(?!\d)[^.]*$/.a/;
            $libperl = find_file($file);
        }

        $dynperl = 0 if !-e $libperl;
    }
}

$static_ldflags =~ s/(^|\s)-l\S*perl\S*(\s|$)/ /g;
$boot_ldflags .= " $static_ldflags";

if ($dynperl) {
    # on Debian derived distros make sure that the Debian package "libperl-dev"
    # is installed (which contains the /usr/lib/libperl.so symlink)
    die qq[You need to install the distro (Debian, Ubuntu etc) package "libperl-dev"\n] 
       if $^O =~ /^(linux|gnukfreebsd)$/i
          && -x "/usr/bin/dpkg"                 
                # probably Debian or a derivative
          && system("dpkg -S $^X >/dev/null 2>&1") == 0 
                # we're building with the system (distro) perl
          && system("dpkg -l libperl-dev >/dev/null 2>&1") != 0;
                # check install status of libperl-dev
} else {
    my $file = $Config{libperl};
    $file = 'libperl.a' if $file eq 'libper'; # same redhat bug? Just making sure...
    $libperl = find_file($file);
    $ldflags = $static_ldflags;
}

my $par = (($dynperl && $^O ne 'os2') ? $boot_exe : $par_exe);

my @strippedparl = qw( Static.pm );
push @strippedparl, qw( Dynamic.pm ) if $dynperl;
my @parl_exes = $parl_exe;
push @parl_exes, $parldyn_exe if $dynperl;

# configure sha1.c
my $sha1_defines = qq[-DBYTEORDER=0x$Config{byteorder}];
$sha1_defines .= qq[ -DU64TYPE="$Config{u64type}"]
    if defined($Config{u64type})
       && ($Config{use64bitint} || length($Config{byteorder}) == 8);

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


WriteMakefile(
    NAME        => "myldr",
    SKIP        => [qw(static static_lib dynamic dynamic_lib)],
    VERSION_FROM => "../lib/PAR/Packer.pm",
    NO_MYMETA   => 1,
    PL_FILES    => {},
    PM          => { map { $_ => catfile('$(INST_LIBDIR)', qw( PAR StrippedPARL ), $_) }
                     @strippedparl },
    EXE_FILES   => \@parl_exes,
    MAN1PODS    => {},
    MAN3PODS    => {},
    macro       => { FIXIN => '$(NOOP)' },
);

sub MY::postamble
{
    my $make_frag = <<"EOT";
LD=$ld
CC=$cc
CFLAGS=$cflags -DLDLIBPTHNAME=\\"$Config{ldlibpthname}\\" -DPARL_EXE=\\"parl$exe\\" -DPAR_PACKER_VERSION=\\"\$(VERSION)\\"
OPTIMIZE=$optimize
LDFLAGS=$Config{ldflags}
PERL_LDFLAGS=$ldflags
STATIC_LDFLAGS=$static_ldflags

OBJECTS=main$o sha1$o $res
MKTMP_STUFF=mktmpdir.c mktmpdir.h utils.c sha1.h

.c$o:
	\$(CC) -c \$(CFLAGS) \$(OPTIMIZE) \$<

pure_all:: $parl_exe Static.pm

main$o: main.c my_par_pl.c perlxsi.c internals.c \$(MKTMP_STUFF)

sha1$o: sha1.c sha1.h
	\$(CC) -c \$(CFLAGS) \$(OPTIMIZE) $sha1_defines sha1.c

$res_section

clean::
	-\$(RM_F) boot_embedded_files.c my_par_pl.c
	-\$(RM_F) $(OBJECTS)
	-\$(RM_F) *.opt *.pdb perlxsi.c
	-\$(RM_F) usernamefrompwuid.h
	-\$(RM_F) $par_exe $boot_exe @parl_exes Dynamic.pm Static.pm

$par_exe: \$(OBJECTS)
	\$(LD) \$(OBJECTS) \$(PERL_LDFLAGS) $out$par_exe_link
	$mt_cmd

my_par_pl.c: $par_pl
	\$(PERLRUN) par_pl2c.pl my_par_pl < $par_pl > \$@ 

$parl_exe: $par
	\$(PERLRUN) -Mblib=.. run_with_inc.pl $par -q -B -O\$@

Static.pm: Static.in $par
	\$(PERLRUN) encode_append.pl Static.in $par Static.pm


.DEFAULT:
	-\$(NOOP)

.SUFFIXES: $o

# dummy targets to satisfy ExtUtils::MakeMaker
dynamic::
static::
test::
EOT

    if ($dynperl)
    {
        my $method;
        for ($^O)
        {
            # sane platforms: use "ldd"
            if (/linux|solaris|freebsd|openbsd|cygwin/i) 
            {
                print STDERR qq[# using "ldd" to find shared libraries needed by $par_exe\n];
                $method = "ldd";
                last;
            }
            # Mac OS X: use "otool -L" if available
            # Note: old versions of otool don't accept --version
            if (/darwin/i && (qx(otool --version 2>&1)   
                              || qx(otool -h /bin/ls 2>&1), $? == 0)) 
            {
                print STDERR qq[# using "otool -L" to find shared libraries needed by $par_exe\n];
                $method = "otool";
                last;
            }
            # Windows with Mingw toolchain: use "objdump" recursively
            if (/mswin32/i && (qx(objdump --version), $? == 0))
            {
                print STDERR qq[# using "objdump" recursively to find DLLs needed by $par_exe\n];
                $method = "recursive_objdump";
                last;
            }

            # fallback
            print STDERR qq[# guessing what DLLs are needed by $par_exe\n];
            $method = "guess";
        }

        $make_frag .= <<"EOT";

pure_all:: $parldyn_exe Dynamic.pm

$parldyn_exe: $par_exe
	\$(PERLRUN) -Mblib=.. run_with_inc.pl $par_exe -q -B -O\$@

boot$o: \$(MKTMP_STUFF) boot_embedded_files.c

$boot_exe: boot$o sha1$o
	\$(LD) boot$o sha1$o $boot_ldflags $res $out$boot_exe_link
	$mt_cmd

boot_embedded_files.c: $par_exe
	\$(PERLRUN) embed_files.pl -c $chunk_size $par_exe $method "$libperl" > \$@

Dynamic.pm: Dynamic.in $par_exe
	\$(PERLRUN) encode_append.pl Dynamic.in $par_exe Dynamic.pm
EOT
    }

    return $make_frag;
}

# local variables:
# mode: cperl
# end:
