#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Config;
use Cwd;
use File::Spec::Functions;
require "./t/utils.pl";

plan skip_all => "Tests only relevant on Windows" unless $^O eq 'MSWin32';

# This test creates two XS modules that demonstrate the problem
# with the perl bindings for Gnome libraries: one glue DLL, XSBar.xs.dll,
# calls a function implemented in another glue DLL, XSQuux.xs.dll
# (i.e. this happens on the C level, **not** in perl callable functions).
# In the Gnome stack almost all glue DLLs call functions from Glib.xs.dll
# and e.g. Gtk2.xs.dll calls functions in Pango.xs.dll and Cairo.xs.dll.

# XXX debug helpers 
use File::Find;
use IPC::Run3;
use Module::ScanDeps; # XXX
diag("FOO Module::ScanDeps version $Module::ScanDeps::VERSION"); # XXX

sub show_tree 
{
    my ($top) = @_;
    my @files;
    find(sub { push @files, $File::Find::name if -f $_ }, $top);
    diag(join("\n", "--- $top ---", (sort @files), "---"));
}

sub show_dlls
{
    my ($install_base, $mod_name) = @_;
    my @mod_parts = split("::", $mod_name);
    my $mod_dll = catfile($install_base, qw(lib perl5), $Config{archname}, 
                          qw(auto), @mod_parts, "$mod_parts[-1].$Config{dlext}");
    diag("FOO $mod_name => $mod_dll");  # XXX

    my ($out, $err);
    run3([qw(objdump -ax), $mod_dll], \undef, \$out, \$err);
    if ($? != 0) 
    {
        diag(qq["objdump -ax $mod_dll" failed:\n$err]);
        return;
    }

    run3([$^X, "-nE", "print if /DLL Name.*/"], \$out, \$err, \$err);
    if ($? != 0) 
    {
        diag(qq[Extracting DLL names from $mod_dll failed:\n$err]);
        return;
    }

    diag("$mod_dll links to:\n$err");
}


my @checks = (
    { 
        code => "use XSQuux; XSQuux::hello();",
        exp  => "hello from XSQuux",
    },
    {
        code => "use XSBar; XSBar::hello();",
        exp  => "hello from XSBar",
    },
    {
        code => "use XSBar; XSBar::calling_into_quux(42);",
        exp  => "calling into quux...\ntriple(42) = 126",
    },
);

plan tests => 8 + 7 * @checks;


# get $(MAKE) from the toplevel Makefile
my $make;       
{
    local $_;
    open my $mk, "<", "Makefile" or die "can't open Makefile: $!";
    while (<$mk>)
    {
        last if ($make) = /^MAKE\s*=\s*(\S+)/;
    }
    close $mk;
}
diag("FOO make = $make");

# create temporary directory to install modules into
my $base = $ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);
my @libs = (catdir($base, qw(lib perl5), $Config{archname}), catdir($base, qw(lib perl5)));

# prepend the new installations to the perl search path for all sub processes
# The reason is that configuring XSBar requires an installed XSQuux:
# - XSQuux/Install/Files.pm (read by ExtUtils::Depends::new() for its depends)
#   (this will add dependencies of XSQuux, though there are none this time)
# - auto/XSQuux/XSQuux.a (added to LIBS by ExtUtils::Depends::find_extra_libs())
#   (this causes XSBar.xs.dll to link to XSQuux.xs.dll)
$ENV{PERL5LIB} = join($Config{path_sep}, @libs, $ENV{PERL5LIB});
diag("FOO PERL5LIB = $ENV{PERL5LIB}"); # XXX

my $cwd = getcwd();
my ($exe, $out, $err);

# build and install XSQuux
diag("build and install XSQuux");
chdir(catdir($cwd, qw(t data XSQuux))) or die "can't chdir to XSQuux source: $!";
run_ok($^X, "Makefile.PL", "INSTALL_BASE=$base");
run_ok($make);
run_ok($make, "install");
run_ok($make, "clean");
show_tree($base);              # XXX
show_dlls($base, "XSQuux");    # XXX

# build and install XSBar
# (XSBar.xs.dll should link to XSQuux.xs.dll)
diag("build and install XSBar");
chdir(catdir($cwd, qw(t data XSBar))) or die "can't chdir to XSBar source: $!";
run_ok($^X, "Makefile.PL", "INSTALL_BASE=$base");
run_ok($make);
run_ok($make, "install");
run_ok($make, "clean");
show_tree($base);              # XXX
show_dlls($base, "XSBar");    # XXX

chdir($cwd) or die "can't chdir back to build dir: $!";

# first round: run code 
foreach (@checks)
{
    diag(qq[running "$_->{code}"...]);
    ($out, $err) = run_ok($^X, "-e", $_->{code});
    is($out, $_->{exp}, "check output");
}

# second round: pack code and run it twice
foreach (@checks)
{
    diag(qq[packing "$_->{code}"...]);
    $exe = pp_ok(-e => $_->{code});
    ($out, $err) = run_ok($exe);
    is($out, $_->{exp}, "check output (first run)");

    TODO: {
        local $TODO = "rschupp/PAR#11" if $_->{code} =~ /XSBar/;

        # run $exe again (with a populated cache directory)
        ($out, $err) = run_ok($exe);
        is($out, $_->{exp}, "check output (second run)");
    }
}


