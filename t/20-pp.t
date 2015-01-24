#!/usr/bin/perl

use strict;
use Cwd;
use Config;
use FindBin;
use File::Spec;
use File::Temp ();
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

chdir File::Spec->catdir($FindBin::Bin, File::Spec->updir);

my $cwd = getcwd();
my $test_dir = File::Spec->catdir($cwd, 'contrib', 'automated_pp_test');

my $parl = File::Spec->catfile($cwd, 'blib', 'script', "parl$Config{_exe}");
my $startperl = $Config{startperl};
$startperl =~ s/^#!//;

my $orig_X = $^X;
my $orig_startperl = $startperl;

if (!-e $parl) {
    print "1..0 # Skip 'parl' not found\n";
    exit;
}
elsif (!($^X = main->can_run($^X))) {
    print "1..0 # Skip '$orig_X' not found\n";
    exit;
}
elsif (!($startperl = main->can_run($startperl))) {
    print "1..0 # Skip '$orig_startperl' not found\n";
    exit;
}

# NOTE: Win32::GetShortPathName exists on cygwin, too
if ($^O eq 'MSWin32' && defined &Win32::GetShortPathName) {
    $^X = lc(Win32::GetShortPathName($^X));
    $startperl = lc(Win32::GetShortPathName($startperl));
}

if (!samefiles($startperl, $^X)) {
    print "1..0 # Skip '$^X' is not the same as '$startperl'\n";
    exit;
}

$ENV{PAR_GLOBAL_CLEAN} = 1;

$ENV{PERL5LIB} = join(
    $Config{path_sep},
    grep length,
        File::Spec->catdir($cwd, 'blib', 'lib'),
        $test_dir,
        $ENV{PERL5LIB},
);

chdir $test_dir;
{
    local @ARGV = (
        "--pp_location"   => File::Spec->catfile($cwd, qw(blib script pp)),
        "--par_location"  => File::Spec->catfile($cwd, qw(blib script par.pl))
    );
    do "automated_pp_test.pl";
}

sub can_run {
    my ($self, $cmd) = @_;

    my $_cmd = $cmd;
    return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

    for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
        my $abs = File::Spec->catfile($dir, $_[1]);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

__END__
