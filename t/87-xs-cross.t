#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Config;
use Cwd;
use File::Spec::Functions;
require "./t/utils.pl";

plan skip_all => "Tests only relevant on Windows" unless $^O eq 'MSWin32';

# Building XS modules XS{Quux,Bar} fails with the  most current release
# of ExtUtils::Depends (0.8001): it doesn't build (and install) the "import lib"
# corresponding to the XS DLL, e.g. XSQuux.a to XSQuux.xs.dll. 
# Without XSQuux.a installed, XSBar.xs.dll fails to link with 
# "undefined reference to `triple'".
#
# This happens at least for perl on Windows built with the mingw-w64 
# toolchain, e.g. Strawberry Perl. Note that the "strawberry" distribution
# installed by shogo82148/actions-setup-perl on GitHub actions
# comes with ExtUtils::Depends 0.8000 pre-installed for this very reason.
#
# Bug reports:
# https://rt.cpan.org/Public/Bug/Display.html?id=147200
# https://rt.cpan.org/Public/Bug/Display.html?id=45224#txn-2466235
#
# NOTE: This bug also prevents people building GNOME bindings 
# (for e.g. Pango, Cairo, Gtk2, Gtk3) with ExtUtils::Depends 0.8001.
use version;
require ExtUtils::Depends;
plan skip_all => "Test XS modules fail to build with ExtUtils::Depends $ExtUtils::Depends::VERSION"
    unless version->parse($ExtUtils::Depends::VERSION) < v0.800.100;

# This test creates two XS modules that demonstrate the problem
# with the perl bindings for Gnome libraries: one glue DLL, XSBar.xs.dll,
# calls a function implemented in another glue DLL, XSQuux.xs.dll
# (i.e. this happens on the C level, **not** in perl callable functions).
# In the Gnome stack almost all glue DLLs call functions from Glib.xs.dll
# and e.g. Gtk2.xs.dll calls functions in Pango.xs.dll and Cairo.xs.dll.


### debug helpers (Windows only)
#use File::Find;
#use IPC::Run3;
#use Module::ScanDeps; 
#
#sub show_tree 
#{
#    my ($top) = @_;
#    my @files;
#    find(sub { push @files, $File::Find::name if -f $_ }, $top);
#    diag(join("\n", "--- $top ---", (sort @files), "---"));
#}
#
#sub show_dlls
#{
#    my ($install_base, $mod_name) = @_;
#    my @mod_parts = split("::", $mod_name);
#    my $mod_dll = catfile($install_base, qw(lib perl5), $Config{archname}, 
#                          qw(auto), @mod_parts, "$mod_parts[-1].$Config{dlext}");
#    diag("XS module $mod_name => $mod_dll");
#
#    my ($out, $err);
#    run3([qw(objdump -ax), $mod_dll], \undef, \$out, \$err);
#    if ($? != 0) 
#    {
#        diag(qq["objdump -ax $mod_dll" failed:\n$err]);
#        return;
#    }
#    run3([$^X, "-nE", "print if /DLL Name.*/"], \$out, \$err, \$err);
#    if ($? != 0) 
#    {
#        diag(qq[Extracting DLL names from $mod_dll failed:\n$err]);
#        return;
#    }
#    diag("$mod_dll links to:\n$err");
#}


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

plan tests => 2 * 4 + 10 * @checks;


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

# create temporary directory to install modules into
my $base = $ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

# prepend the new installations to the perl search path for all sub processes
# The reason is that configuring XSBar requires an installed XSQuux:
# - XSQuux/Install/Files.pm (read by ExtUtils::Depends::new() for its depends)
#   (this will add dependencies of XSQuux, though there are none this time)
# - auto/XSQuux/XSQuux.a (added to LIBS by ExtUtils::Depends::find_extra_libs())
#   (this causes XSBar.xs.dll to link to XSQuux.xs.dll)
{
    my $perl5lib = catdir($base, qw(lib perl5));
    $perl5lib .= "$Config{path_sep}$ENV{PERL5LIB}" if $ENV{PERL5LIB};
    $ENV{PERL5LIB} = $perl5lib;
}

my $cwd = getcwd();
my ($exe, $out, $err);

foreach my $mod (qw(XSQuux XSBar))      # must build XSQuux **before** XSBar
{
    diag("build and install $mod");
    chdir(catdir($cwd, qw(t data), $mod)) or die "can't chdir to $mod source: $!";
    run_ok($^X, "Makefile.PL", "INSTALL_BASE=$base");
    run_ok($make);
    run_ok($make, "install");
    run_ok($make, "clean");
    # DEBUG show_tree($base);      
    # DEBUG show_dlls($base, $mod);

}

chdir($cwd) or die "can't chdir back to build dir: $!";


# first round: run code (2 checks each)
foreach (@checks)
{
    diag(qq[running "$_->{code}"...]);
    ($out, $err) = run_ok($^X, "-e", $_->{code});
    is($out, $_->{exp}, "check output");
}

# second round: pack code and run it twice (5 checks each)
foreach (@checks)
{
    diag(qq[packing "$_->{code}"...]);
    $exe = pp_ok(-e => $_->{code});
    ($out, $err) = run_ok($exe);
    is($out, $_->{exp}, "check output (first run)");

    # run $exe again (with a populated cache directory)
    ($out, $err) = run_ok($exe);
    is($out, $_->{exp}, "check output (second run)");
}

# third round: pack code with "--clean" and run it (3 checks each)
foreach (@checks)
{
    diag(qq[packing "$_->{code}" with --clean ...]);
    $exe = pp_ok("--clean", -e => $_->{code});
    ($out, $err) = run_ok($exe);
    is($out, $_->{exp}, "check output (with --clean)");
}
