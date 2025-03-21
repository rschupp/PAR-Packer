package pp; # Now people can say "install pp" in the CPAN shell.
use 5.006;
use strict;
use warnings;
use PAR::Packer ();

# This line is here so CPAN.pm can parse a $VERSION from us...
our $VERSION = '0.992';

# ...but we read our $VERSION again from PAR::Packer in case we forgot to update
# the $VERSION above during release engineering.
$VERSION = $PAR::Packer::VERSION;

use PAR ();
use Module::ScanDeps ();
use App::Packer::PAR ();
use Getopt::ArgvFile default=>1, resolveEnvVars=>1;
use Getopt::Long qw(:config no_ignore_case);


sub go {
    my $class = shift;

    if ($ENV{PP_OPTS}) {
        require Text::ParseWords;
        unshift @ARGV, Text::ParseWords::shellwords($ENV{PP_OPTS});
    }

    my %opt;
    GetOptions( \%opt, PAR::Packer->options, 'h|help', 'V|version' )
        or die qq[Run "$0 --help" to show available options.\n];
    help() if $opt{h};
    version() if $opt{V};

    local $Module::ScanDeps::ScanFileRE = qr/./;

    App::Packer::PAR->new(
        frontend    => 'Module::ScanDeps',
        backend     => 'PAR::Packer',
        frontopts   => \%opt,
        backopts    => \%opt,
        args        => \@ARGV,
    )->go;

    return 1;
}

sub help {
    print "PAR Packager, version $VERSION (PAR version $PAR::VERSION)\n\n";
    {
        no warnings;
        exec "perldoc $0";
        exec "pod2text $0";
    }
    version();
}

sub version {
    print << ".";
PAR Packager, version $VERSION (PAR version $PAR::VERSION)
Copyright 2002-2009 by Audrey Tang <cpan\@audreyt.org>

Neither this program nor the associated "parl" program impose any
licensing restrictions on files generated by their execution, in
accordance with the 8th article of the Artistic License:

        "Aggregation of this Package with a commercial distribution is
        always permitted provided that the use of this Package is embedded;
        that is, when no overt attempt is made to make this Package's
        interfaces visible to the end user of the commercial distribution.
        Such use shall not be construed as a distribution of this Package."

Therefore, you are absolutely free to place any license on the resulting
executable, as long as the packed 3rd-party libraries are also available
under the Artistic License.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  There is NO warranty; not even for
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

.
    exit;
}

__END__

=head1 NAME

pp - PAR Packager

=head1 SYNOPSIS

B<pp> S<[ B<-ABCEFILMPTSVXacdefghilmnoprsuvxz> ]> S<[ I<parfile> | I<scriptfile> ]>...

=head1 EXAMPLES

Note: When running on Microsoft Windows, the F<a.out> below will be
replaced by F<a.exe> instead.

    % pp hello.pl               # Pack 'hello.pl' into executable 'a.out'
    % pp -o hello hello.pl      # Pack 'hello.pl' into executable 'hello'
                                # (or 'hello.exe' on Win32)

    % pp -o foo foo.pl bar.pl   # Pack 'foo.pl' and 'bar.pl' into 'foo'
    % ./foo                     # Run 'foo.pl' inside 'foo'
    % mv foo bar; ./bar         # Run 'bar.pl' inside 'foo'
    % mv bar baz; ./baz         # Error: Can't open perl script "baz"

    % pp -p file                # Creates a PAR file, 'a.par'
    % pp -o hello a.par         # Pack 'a.par' to executable 'hello'
    % pp -S -o hello file       # Combine the two steps above

    % pp -p -o out.par file     # Creates 'out.par' from 'file'
    % pp -B -p -o out.par file  # same as above, but bundles core modules
                                # and removes any local paths from @INC
    % pp -P -o out.pl file      # Creates 'out.pl' from 'file'
    % pp -B -p -o out.pl file   # same as above, but bundles core modules
                                # and removes any local paths from @INC
                                # (-B is assumed when making executables)

    % pp -e "print 123"         # Pack a one-liner into 'a.out'
    % pp -p -e "print 123"      # Creates a PAR file 'a.par'
    % pp -P -e "print 123"      # Creates a perl script 'a.pl'

    % pp -c hello               # Check dependencies from "perl -c hello"
    % pp -x hello               # Check dependencies from "perl hello"
    % pp -n -x hello            # same as above, but skips static scanning

    % pp -I /foo hello          # Extra include paths
    % pp -M Foo::Bar hello      # Extra modules in the include path
    % pp -M abbrev.pl hello     # Extra libraries in the include path
    % pp -X Foo::Bar hello      # Exclude modules
    % pp -a data.txt hello      # Additional data files

    % pp -r hello               # Pack 'hello' into 'a.out', runs 'a.out'
    % pp -r hello a b c         # Pack 'hello' into 'a.out', runs 'a.out'
                                # with arguments 'a b c'

    % pp hello --log=c          # Pack 'hello' into 'a.out', logs
                                # messages into 'c'

    # Pack 'hello' into a console-less 'out.exe' (Win32 only)
    % pp --gui -o out.exe hello

    % pp @file hello.pl         # Pack 'hello.pl' but read _additional_
                                # options from file 'file'

=head1 DESCRIPTION

F<pp> creates standalone executables from Perl programs, using the
compressed packager provided by L<PAR>, and dependency detection
heuristics offered by L<Module::ScanDeps>.  Source files are compressed
verbatim without compilation.

You may think of F<pp> as "F<perlcc> that works without hassle". :-)

A GUI interface is also available as the F<tkpp> command.

It does B<not> provide the compilation-step acceleration provided by
F<perlcc> (however, see B<-f> below for byte-compiled, source-hiding
techniques), but makes up for it with better reliability, smaller
executable size, and full retrieval of original source code.

When a single input program is specified, the resulting executable will
behave identically as that program.  However, when multiple programs
are packaged, the produced executable will run the one that has the
same basename as C<$0> (i.e. the filename used to invoke it).  If
nothing matches, it dies with the error C<Can't open perl script "$0">.

=head1 OPTIONS

Options are available in a I<short> form and a I<long> form.  For
example, the three lines below are all equivalent:

    % pp -o output.exe input.pl
    % pp --output output.exe input.pl
    % pp --output=output.exe input.pl

Since the command lines can become sufficiently long to reach the limits
imposed by some shells, it is possible to have F<pp> read some of its
options from one or more text files. The basic usage is to just include
an argument starting with an 'at' (@) sigil. This argument will be
interpreted as a file to read options from. Mixing ordinary options
and C<@file> options is possible. This is implemented using the
L<Getopt::ArgvFile> module, so read its documentation for advanced usage.
Note that L<Getopt::ArgvFile> is used here with parameter C<resolveEnvVars=1>,
i.e. substrings of the form C<${>I<FOO>C<}> in the contents of C<@file> are replaced
with the value of environment variable I<FOO>.

=over 4

=item B<-a>, B<--addfile>=I<FILE>|I<DIR>

Add an extra file into the package.  If the file is a directory, recursively
add all files inside that directory, with links turned into actual files.

By default, files are placed under C</> inside the package with their
original names.  You may override this by appending the target filename
after a C<;>, like this:

    % pp -a "old_filename.txt;new_filename.txt"
    % pp -a "old_dirname;new_dirname"

You may specify C<-a> multiple times.

=item B<-A>, B<--addlist>=I<FILE>

Read a list of file/directory names from I<FILE>, adding them into the
package.  Each line in I<FILE> is taken as an argument to B<-a> above.

You may specify C<-A> multiple times.

=item B<-B>, B<--bundle>

Bundle core modules in the resulting package.  This option is enabled
by default, except when C<-p> or C<-P> is specified.

Since PAR version 0.953, this also strips any local paths from the
list of module search paths C<@INC> before running the contained
script.

=item B<-C>, B<--clean>

Clean up temporary files extracted from the application at runtime.
By default, these files are cached in the temporary directory; this
allows the program to start up faster next time.

=item B<-c>, B<--compile>

Run C<perl -c inputfile> to determine additional run-time dependencies.

=item B<-cd>, B<--cachedeps>=I<FILE>

Use I<FILE> to cache detected dependencies. Creates I<FILE> unless
present. This will speed up the scanning process on subsequent runs.

=item B<-d>, B<--dependent>

Reduce the executable size by not including a copy of perl interpreter.
Executables built this way will need a separate F<perl5x.dll>
or F<libperl.so> to function correctly.  This option is only available
if perl is built as a shared library.

=item B<-e>, B<--eval>=I<STRING>

Package a one-liner, much the same as C<perl -e '...'>

=item B<-E>, B<--evalfeature>=I<STRING>

Behaves just like C<-e>, except that it implicitly enables all optional features
(in the main compilation unit) with Perl 5.10 and later.  See L<feature>.

=item B<-x>, B<--execute>

Run C<perl inputfile> to determine additional run-time dependencies.

Using this option, F<pp> may be able to detect the use of modules that
can't be determined by static analysis of C<inputfile>. Examples
are stuff loaded by run-time loaders like L<Module::Runtime> or
"plugin" loaders like L<Module::Loader>. Note that which modules are
detected depends on which parts of your program are exercised
when running C<inputfile>. E.g. if your program immediately terminates
when run as C<perl inputfile> because it lacks mandatory arguments,
then this option will probably have no effect. You may use B<--xargs> to
supply arguments in this case.

=item B<--xargs>=I<STRING>

If B<-x> is given, splits the C<STRING> using the function
C<shellwords> from L<Text::ParseWords> and passes the result
as C<@ARGV> when running C<perl inputfile>.

=item B<-X>, B<--exclude>=I<MODULE>

Exclude the given module from the dependency search path and from the
package. If the given file is a zip or par or par executable, all the files
in the given file (except MANIFEST, META.yml and script/*) will be
excluded and the output file will "use" the given file at runtime.

=item B<-f>, B<--filter>=I<FILTER>

Filter source script(s) with a L<PAR::Filter> subclass.  You may specify
multiple such filters.

If you wish to hide the source code from casual prying, this will do:

    % pp -f Bleach source.pl

If you are more serious about hiding your source code, you should have
a look at Steve Hay's L<PAR::Filter::Crypto> module. Make sure you
understand the Filter::Crypto caveats!

Note: Most filters are incompatible with C<__DATA__> sections in your source.
The packed executable typically aborts with an error message like

  readline() on unopened filehandle DATA at (eval 13) line 3.

=item B<-g>, B<--gui>

Build an executable that does not have a console window. This option is
ignored on non-MSWin32 platforms or when C<-p> is specified.

=item B<-h>, B<--help>

Show basic usage information.

=item B<-I>, B<--lib>=I<DIR>

Add the given directory to the perl module search path.  May
be specified multiple times.

=item B<-l>, B<--link>=I<FILE>|I<LIBRARY>

Add the given shared library (a.k.a. shared object or DLL) into the
packed file.  Also accepts names under library paths; i.e.
C<-l ncurses> means the same thing as C<-l libncurses.so> or
C<-l /usr/local/lib/libncurses.so> in most Unixes.  May be specified
multiple times.

=item B<-L>, B<--log>=I<FILE>

Log the output of packaging to a file rather than to stdout.

=item B<-F>, B<--modfilter>=I<FILTER[=REGEX]>,

Filter included perl module(s) with a L<PAR::Filter> subclass.
You may specify multiple such filters.

By default, the I<PodStrip> filter is applied.  In case
that causes trouble, you can turn this off by setting the
environment variable C<PAR_VERBATIM> to C<1>.

Since PAR 0.958, you can use an optional regular expression (I<REGEX> above)
to select the files in the archive which should be filtered. The regular expression
is matched against module names as they would appear as keys in %INC,
e.g. C<Foo/Bar.pm> for module C<Foo::Bar>.  Examples:

  pp -o foo.exe -F 'Bleach=warnings\.pm$' foo.pl

This creates a binary executable F<foo.exe> from F<foo.pl> packaging all files
as usual except for files ending in C<warnings.pm> which are filtered with
L<PAR::Filter::Bleach>.

  pp -o foo.exe -F 'Bleach=^(?!Win32/)' foo.pl

This "bleaches" all modules B<except> those in the C<Win32::> namespace.

Note: The same restriction on C<__DATA__> sections holds as for B<--filter>.

=item B<-M>, B<--module>=I<MODULE>

Add the specified module into the package, along with its dependencies.

The following variants may be used to add whole module namespaces:

=over 4

=item B<-M Foo::**>

Add every module in the C<Foo> namespace B<except> C<Foo> itself, i.e.
add C<Foo::Bar>, C<Foo::Bar::Quux> etc up to any depth.

=item B<-M Foo::*>

Add every module at level 1 in the C<Foo> namespace, i.e.
add C<Foo::Bar>, but B<neither> C<Foo::Bar::Quux> B<nor> C<Foo>.

=item B<-M Foo::>

Shorthand for C<-M Foo -M Foo:**>: every module in the C<Foo> namespace
including C<Foo> itself.

=back

Instead of a module name, I<MODULE> may also be specified as a filename
relative to the C<@INC> path, i.e.  C<-M Module/ScanDeps.pm>
means the same thing as C<-M Module::ScanDeps>.

If I<MODULE> has an extension that is not C<.pm>/C<.ix>/C<.al>, it will not
be scanned for dependencies, and will be placed under C</> instead of
C</lib/> inside the PAR file.  This use is B<deprecated> -- consider using
the B<-a> option instead.

You may specify C<-M> multiple times.

=item B<-m>, B<--multiarch>

Build a multi-architecture PAR file.  Implies B<-p>.

=item B<-n>, B<--noscan>

Skip the default static scanning altogether, using run-time
dependencies from B<-c> or B<-x> exclusively.

=item B<-N>, B<--namespace>=I<NAMESPACE>

Add all modules in the namespace into the package,
along with their dependencies. If C<NAMESPACE> is something like C<Foo::Bar>
then this will add all modules C<Foo/Bar/Quux.pm>, C<Foo/Bar/Fred/Barnie.pm> etc
that can be located in your module search path. It mimics the behaviour
of "plugin" loaders like L<Module::Loader>.

This is different from using C<-M Foo::Bar::>, as the latter insists
on adding C<Foo/Bar.pm> which might not exist in the above "plugin" scenario.

You may specify C<-N> multiple times.

=item B<-o>, B<--output>=I<FILE>

File name for the final packaged executable.

=item B<-p>, B<--par>

Create PAR archives only; do not package to a standalone binary.

=item B<-P>, B<--perlscript>

Create stand-alone perl script; do not package to a standalone binary.

=item B<-r>, B<--run>

Run the resulting packaged script after packaging it.

=item B<--reusable>

B<EXPERIMENTAL>

Make the packaged executable reusable for running arbitrary, external
Perl scripts as if they were part of the package:

  pp -o myapp --reusable someapp.pl
  ./myapp --par-options --reuse otherapp.pl

The second line will run F<otherapp.pl> instead of F<someapp.pl>.

=item B<-S>, B<--save>

Do not delete generated PAR file after packaging.

=item B<-s>, B<--sign>

Cryptographically sign the generated PAR or binary file using
L<Module::Signature>.

=item B<-T>, B<--tempcache>

Set the program unique part of the cache directory name that is used
if the program is run without -C. If not set, a hash of the executable
is used.

When the program is run, its contents are extracted to a temporary
directory.  On Unix systems, this is commonly
F</tmp/par-USER/cache-XXXXXXX>.  F<USER> is replaced by the
name of the user running the program, but "spelled" in hex.
F<XXXXXXX> is either a hash of the
executable or the value passed to the C<-T> or C<--tempcache> switch.

=item B<-u>, B<--unicode>

Note: This option is ignored for Perl 5.32 and above.

Package Unicode support (essentially F<utf8_heavy.pl> and everything
below the directory F<unicore> in your perl library).

This option exists because it is impossible to detect using static analysis
whether your program needs Unicode support at runtime. (Note: If your
program contains C<use utf8> this does B<not> imply it needs Unicode
support. It merely says that your program source is written in UTF-8.)

If your packed program exits with an error message like

  Can't locate utf8_heavy.pl in @INC (@INC contains: ...)

try to pack it with C<-u> (or use C<-x>).

=item B<-v>, B<--verbose>[=I<NUMBER>]

Increase verbosity of output; I<NUMBER> is an integer from C<1> to C<3>,
C<3> being the most verbose.  Defaults to C<1> if specified without an
argument.  Alternatively, B<-vv> sets verbose level to C<2>, and B<-vvv>
sets it to C<3>.

=item B<-V>, B<--version>

Display the version number and copyrights of this program.

=item B<-z>, B<--compress>=I<NUMBER>

Set zip compression level; I<NUMBER> is an integer from C<0> to C<9>,
C<0> = no compression, C<9> = max compression.  Defaults to C<6> if
B<-z> is not used.

=back

=head1 ENVIRONMENT

=over 4

=item PP_OPTS

Command-line options (switches).  Switches in this variable are taken
as if they were on every F<pp> command line.

=back

=head1 NOTES

Here are some recipes showing how to utilize F<pp> to bundle
F<source.pl> with all its dependencies, on target machines with
different expected settings:

=over 4

=item Stone-alone setup:

To make a stand-alone executable, suitable for running on a
machine that doesn't have perl installed:


    % pp -o packed.exe source.pl        # makes packed.exe
    # Now, deploy 'packed.exe' to target machine...
    % packed.exe                        # run it

=item Perl interpreter only, without core modules:

To make a packed .pl file including core modules, suitable
for running on a machine that has a perl interpreter, but where
you want to be sure of the versions of the core modules that
your program uses:

    % pp -B -P -o packed.pl source.pl   # makes packed.pl
    # Now, deploy 'packed.pl' to target machine...
    % perl packed.pl                    # run it

=item Perl with core modules installed:

To make a packed .pl file without core modules, relying on the target
machine's perl interpreter and its core libraries.  This produces
a significantly smaller file than the previous version:

    % pp -P -o packed.pl source.pl      # makes packed.pl
    # Now, deploy 'packed.pl' to target machine...
    % perl packed.pl                    # run it

=item Perl with PAR.pm and its dependencies installed:

Make a separate archive and executable that uses the archive. This
relies upon the perl interpreter and libraries on the target machine.

    % pp -p source.pl                   # makes source.par
    % echo "use PAR 'source.par';" > packed.pl;
    % cat source.pl >> packed.pl;       # makes packed.pl
    # Now, deploy 'source.par' and 'packed.pl' to target machine...
    % perl packed.pl                    # run it, perl + core modules required

=back

Note that even if your perl was built with a shared library, the
'Stand-alone executable' above will I<not> need a separate F<perl5x.dll>
or F<libperl.so> to function correctly.  But even in this case, the
underlying system libraries such as I<libc> must be compatible between
the host and target machines.  Use C<--dependent> if you
are willing to ship the shared library with the application, which
can significantly reduce the executable size.

=head1 SEE ALSO

L<tkpp>, L<par.pl>, L<parl>, L<perlcc>

L<PAR::Packer::Troubleshooting>, L<App::PP::Autolink>, 
L<PAR>, L<PAR::Packer>, L<Module::ScanDeps> 

L<Getopt::Long>, L<Getopt::ArgvFile>

=head1 ACKNOWLEDGMENTS

Simon Cozens, Tom Christiansen and Edward Peschko for writing
F<perlcc>; this program try to mimic its interface as close
as possible, and copied liberally from their code.

Jan Dubois for writing the F<exetype.pl> utility, which has been
partially adapted into the C<-g> flag.

Mattia Barbon for providing the C<myldr> binary loader code.

Jeff Goff for suggesting the name F<pp>.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>,
Steffen Mueller E<lt>smueller@cpan.orgE<gt>
Roderich Schupp E<lt>roderich.schupp@gmail.comE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.
Archives of the mailing list are available at
E<lt>https://www.mail-archive.com/par@perl.org/E<gt> or E<lt>https://groups.google.com/g/perl.parE<gt>.

Please submit bug reports to E<lt>https://github.com/rschupp/PAR-Packer/issuesE<gt>.

=head1 COPYRIGHT

Copyright 2002-2009 by Audrey Tang
E<lt>cpan@audreyt.orgE<gt>.

Neither this program nor the associated L<parl> program impose any
licensing restrictions on files generated by their execution, in
accordance with the 8th article of the Artistic License:

    "Aggregation of this Package with a commercial distribution is
    always permitted provided that the use of this Package is embedded;
    that is, when no overt attempt is made to make this Package's
    interfaces visible to the end user of the commercial distribution.
    Such use shall not be construed as a distribution of this Package."

Therefore, you are absolutely free to place any license on the resulting
executable, as long as the packed 3rd-party libraries are also available
under the Artistic License.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut
