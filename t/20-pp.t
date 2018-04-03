#!/usr/bin/perl

use strict;
use Cwd;
use Config;
use FindBin;
use File::Spec::Functions qw( :ALL );
use File::Temp qw( tempdir );
use ExtUtils::MakeMaker;

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

sub samefiles {
    my ($f1, $f2) = @_;
    $f1 eq $f2 and return 1;
    -e $f1 && -e $f2 or return 0;
    -s $f1 == -s $f2 or return 0;
    local $/ = \65536;
    open my $fh1, '<', $f1 or return 0;
	open my $fh2, '<', $f2 or return 0;
    while (1) {
		my $c1 = <$fh1>;
		my $c2 = <$fh2>;
		last if !defined $c1 and !defined $c2;
		return 0 if !defined $c1 or !defined $c2;
		return 0 if $c1 ne $c2;
    }
    return 1;
}

chdir catdir($FindBin::Bin, updir());

my $cwd = getcwd();
my $test_dir = catdir($cwd, 'contrib', 'automated_pp_test');

my $parl = catfile($cwd, 'blib', 'script', "parl$Config{_exe}");

my $orig_X = $^X;

if (!-e $parl) {
    print "1..0 # Skip 'parl' not found\n";
    exit;
}
if (!($^X = main->can_run($^X))) {
    print "1..0 # Skip '$orig_X' not found\n";
    exit;
}

# NOTE: Win32::GetShortPathName exists on cygwin, too
if ($^O eq 'MSWin32' && defined &Win32::GetShortPathName) {
    $^X = lc(Win32::GetShortPathName($^X));
}

$ENV{PAR_GLOBAL_CLEAN} = 1;

$ENV{PERL5LIB} = join(
    $Config{path_sep},
    grep length,
        catdir($cwd, 'blib', 'lib'),
        $test_dir,
        $ENV{PERL5LIB},
);

chdir $test_dir or die "can't chdir to $test_dir: $!";
push @INC, $test_dir;
{
    local @ARGV = (
        "--pp_location"   => catfile($cwd, qw(blib script pp)),
        "--par_location"  => catfile($cwd, qw(blib script par.pl)),
        (defined($ENV{TEST_VERBOSE}) && $ENV{TEST_VERBOSE} > 1) ? ("--verbose") : ()
    );
    do "./automated_pp_test.pl";
}

sub can_run {
    my ($self, $cmd) = @_;

    my $_cmd = $cmd;
    return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

    for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
        my $abs = catfile($dir, $_[1]);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

__END__
