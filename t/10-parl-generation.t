#!/usr/bin/perl -w
use strict;
use constant TEST_NO => 31;
use Test::More tests => TEST_NO;

use File::Spec::Functions qw( :ALL );
use File::Temp qw( tempdir tempfile );
use FindBin ();
use Config qw/%Config/;
use vars qw/@INC %INC/;

$ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

unshift @INC, ($FindBin::Bin);
use_ok('PAR');
use_ok('PAR::StrippedPARL::Static');
use_ok('PAR::StrippedPARL::Dynamic');

# define all the file locations
my $builddir = catdir($FindBin::Bin, updir());
my $myldr    = catdir($builddir, 'myldr');
my $boot     = catfile($myldr, 'boot' . $Config{_exe});
my $dynamic  = catfile($myldr, 'par' . $Config{_exe});
my $parl     = catfile($myldr, 'parl' . $Config{_exe});
my $parldyn  = catfile($myldr, 'parldyn' . $Config{_exe});

# static(.exe), parl(.exe) must exist
ok(-f $boot, 'Found the static build of parl in myldr');

if (not -f $boot) {
    SKIP: {
        skip "No boot found. Test script cannot continue!", TEST_NO()-4;
    }
    exit();
}

ok(-f $parl,   'Found parl in script');


# check that get_raw() returns the same as myldr/boot(.exe)
my $static_bin;
eval { $static_bin = PAR::StrippedPARL::Static->get_raw(); };
ok(!$@, 'Running ...Static->get_raw didn\'t complain' . ($@?": $@":''));
ok($static_bin, '...Static->get_raw didn\'t return false');

my $static_length = length($static_bin);

# compare file sizes
is(
    $static_length,
    -s $boot,
    'Binary returned from ->get_raw has the same size as myldr/boot(.exe)'
);

# compare data
{
    open my $fh, '<', $boot or die $!;
    binmode $fh;
    local $/ = undef;
    ok(
        $static_bin eq <$fh>,
        '...Static->get_raw returns exact myldr/boot(.exe)'
    );
    close $fh;
}

# check that write_raw() writes the same as myldr/boot(.exe)
my $static_tmp_file;
{
    my $tfh;
    ($tfh, $static_tmp_file) = tempfile( 'partestXXXXXX', OPEN => 1, TMPDIR => 1 );
}

{
    my $okay;
    eval { $okay = PAR::StrippedPARL::Static->write_raw($static_tmp_file); };
    ok(!$@, 'Running ...Static->write_raw didn\'t complain' . ($@?": $@":''));
    ok($okay, '...Static->write_raw didn\'t return false');
}
ok(-f $static_tmp_file, '...Static->write_raw created file');

# compare file sizes
is(
    -s $static_tmp_file,
    -s $boot,
    'Binary created by ->write_raw has the same size as myldr/boot(.exe)'
);

# compare data
{
    open my $fh, '<', $static_tmp_file or die $!;
    binmode $fh;
    local $/ = undef;
    ok(
        $static_bin eq <$fh>,
        '...Static->get_raw returns exact same as write_raw writes'
    );
    close $fh;
}


# check that write_parl() writes the same as script/parl(.exe)
my $parl_tmp_file;
{
    my $tfh;
    ($tfh, $parl_tmp_file) = tempfile( 'partest2XXXXXX', OPEN => 1, TMPDIR => 1 );
}


{
    my $okay;
    eval { $okay = PAR::StrippedPARL::Static->write_parl($parl_tmp_file); };
    ok(!$@, 'Running ...Static->write_parl didn\'t complain' . ($@?": $@":''));
    ok($okay, '...Static->write_parl didn\'t return false');
}

ok(-f $parl_tmp_file, '...Static->write_parl created file');
ok(-s $parl_tmp_file, '...Static->write_parl created non-empty file');



###############################################################
#
# If true, run the dynamic tests below
my $have_dynamic = -f $dynamic;

my $dyn_tmp_file;
my $parldyn_tmp_file;

SKIP: {
    skip "No parldyn found", 13 unless $have_dynamic;
    

    # check that get_raw() returns the same as myldr/par(.exe)
    my $dyn_bin;
    eval { $dyn_bin = PAR::StrippedPARL::Dynamic->get_raw(); };
    ok(!$@, 'Running ...Dynamic->get_raw didn\'t complain' . ($@?": $@":''));
    ok($dyn_bin, '...Dynamic->get_raw didn\'t return false');

    my $dyn_length = length($dyn_bin);

    # compare file sizes
    is(
        $dyn_length,
        -s $dynamic,
        'Dynamic binary returned from ->get_raw has the same size as myldr/par(.exe)'
    );
    
    # compare data
    {
        open my $fh, '<', $dynamic or die $!;
        binmode $fh;
        local $/ = undef;
        ok(
            $dyn_bin eq <$fh>,
            '...Dynamic->get_raw returns exact myldr/par(.exe)'
        );
    close $fh;
    }

    # check that write_raw() writes the same as myldr/par(.exe)
    {
        my $tfh;
        ($tfh, $dyn_tmp_file) = tempfile( 'partestXXXXXX', OPEN => 1, TMPDIR => 1 );
    }
    
    {
        my $okay;
        eval { $okay = PAR::StrippedPARL::Dynamic->write_raw($dyn_tmp_file); };
        ok(!$@, 'Running ...Dynamic->write_raw didn\'t complain' . ($@?": $@":''));
        ok($okay, '...Dynamic->write_raw didn\'t return false');
    }
    ok(-f $dyn_tmp_file, '...Dynamic->write_raw created file');

    # compare file sizes
    is(
        -s $dyn_tmp_file,
        -s $dynamic,
        'Dynamic binary created by ->write_raw has the same size as myldr/par(.exe)'
    );

    # compare data
    {
        open my $fh, '<', $dyn_tmp_file or die $!;
        binmode $fh;
        local $/ = undef;
        ok(
            $dyn_bin eq <$fh>,
        '...Dynamic->get_raw returns exact same as write_raw writes'
        );
        close $fh;
    }

    # check that write_parl() writes the same as myldr/parldyn(.exe)
    {
        my $tfh;
        ($tfh, $parldyn_tmp_file) = tempfile( 'partest2XXXXXX', OPEN => 1, TMPDIR => 1 );
    }

    {
        my $okay;
        eval {
            $okay = PAR::StrippedPARL::Dynamic->write_parl($parldyn_tmp_file);
        };
        ok(!$@, 'Running ...Dynamic->write_parl didn\'t complain' . ($@?": $@":''));
        ok($okay, '...Dynamic->write_parl didn\'t return false');
    }

    ok(-f $parldyn_tmp_file, '...Dynamic->write_parl created file');
    ok(-s $parldyn_tmp_file, '...Dynamic->write_parl created non-empty file');
}


END {
    for (
        grep defined,
        $static_tmp_file, $parl_tmp_file, $dyn_tmp_file, $parldyn_tmp_file
    ) {
        unlink($_);
    }
}
