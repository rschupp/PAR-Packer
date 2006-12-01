#!/usr/bin/perl

use 5.006;
use inc::Module::Install;

name        'PAR';
abstract    'Perl Archive Tookit';
all_from    'lib/PAR.pm';

requires    'File::Temp'        => 0.05;
requires    'Compress::Zlib'    => ($^O eq 'MSWin32') ? 1.16 : 1.30;
requires    'Archive::Zip'      => 1.00;
requires    'Module::ScanDeps'  => 0.69;
requires    'PAR::Dist'         => 0.21;
requires    'Getopt::ArgvFile'  => 1.07;

if ($^O eq 'MSWin32') {
    feature 'Windows --icon and --info support',
    recommends
            'Parse::Binary'     => 0.04,
            'Win32::Exe'        => 0.04;
}

if (can_use('Crypt::OpenPGP') or can_run('gpg')) {
    my $has_sha1 = (
        can_use('Digest::SHA1') or
        can_use('Digest::SHA')  or
        can_use('Digest::SHA::PurePerl')
    );

    feature 'Digital signature support',
    recommends
            'Digest',
            ($has_sha1 ? () : (can_cc() ? 'Digest::SHA'
                                        : 'Digest::SHA::PurePerl')),
            'Module::Signature';
}

include_deps        'Test::More';
no_index            directory => 'contrib';
auto_install_now    -default => 0;
auto_provides;

par_base 'SMUELLER';

par_prehook();
WriteAll sign => 1;
par_posthook();

my %no_parl  = ();

use strict; use warnings;
sub par_prehook {
    my $bork = $no_parl{$^O};
    my $cc;
    $cc = can_cc unless $bork;
    my $par;
    $par = fetch_par('', '', !$cc) unless ($cc or $bork);
    my $exe  = $Config::Config{_exe};
    my $dynperl = $Config::Config{useshrplib} && ($Config::Config{useshrplib} ne 'false');

    if ($bork) {
        warn "Binary loading known to fail on $^O; won't generate 'script/parl$exe'!\n";
    }
    elsif (!$par and !$cc) {
        warn "No compiler found, won't generate 'script/parl$exe'!\n";
    }

    # XXX: this branch is currently not entered
    if ($cc and $par) {
        my $answer = prompt(
            "*** Pre-built PAR package found.  Use it instead of recompiling [y/N]?"
        );
        if ($answer !~ /^[Yy]/) {
            load('preamble')->{preamble} = '';
            $par = '';
        }
    } 

    my @bin = ("script/parl$exe", "myldr/par$exe");
    push @bin, ("script/parldyn$exe", "myldr/static$exe") if $dynperl;

    $FindBin::Bin = '.' unless -e "$FindBin::Bin/Makefile.PL";
    my $par_exe = "$FindBin::Bin/$bin[1]";

    if ($par) {
        open my $fh, '>', $par_exe or die "Cannot write to $par_exe";
        close $fh;
    }
    elsif (-f $par_exe and not -s $par_exe) {
        unlink $par_exe;
    }

    clean_files(@bin) if $par or $cc;

    makemaker_args(
        MAN1PODS		=> {
            'script/par.pl'	=> 'blib/man1/par.pl.1',
            'script/pp'	        => 'blib/man1/pp.1',
            'script/tkpp'       => 'blib/man1/tkpp.1',
          ($par or $cc) ? (
            'script/parl.pod'   => 'blib/man1/parl.1',
          ) : (),
        },
        EXE_FILES		=> [
            'script/par.pl',
            'script/pp',
            'script/tkpp',
          (!$par and $cc) ? (
            "script/parl$exe",
            $dynperl ? (
                "script/parldyn$exe",
            ) : (),
          ) : (),
        ],
        DIR                     => [
          (!$par and $cc) ? (
            'myldr'
          ) : (),
        ],
        NEEDS_LINKING	        => 1,
    );
}

sub par_posthook {
    my $exe = $Config::Config{_exe};
    return unless $exe eq '.exe';

    open my $in, '<', "$FindBin::Bin/Makefile" or return;
    open my $out, '>', "$FindBin::Bin/Makefile.new" or return;
    while (<$in>) {
        next if /^\t\$\(FIXIN\) .*\Q$exe\E$/;
        next if /^\@\[$/ or /^\]$/;
        print $out $_;
    }
    close $out;
    close $in;
    unlink "$FindBin::Bin/Makefile";
    rename "$FindBin::Bin/Makefile.new" => "$FindBin::Bin/Makefile";
}

1;
