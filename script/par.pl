#!/usr/bin/perl
eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

package __par_pl;

# --- This script must not use any modules at compile time ---
# use strict;

=head1 NAME

par.pl - Make and run Perl Archives

=head1 SYNOPSIS

(Please see L<pp> for convenient ways to make self-contained
executables, scripts or PAR archives from perl programs.)

To make a I<PAR distribution> from a CPAN module distribution:

    % par.pl -p                 # make a PAR dist under the current path
    % par.pl -p Foo-0.01        # assume unpacked CPAN dist in Foo-0.01/

To manipulate a I<PAR distribution>:

    % par.pl -i Foo-0.01-i386-freebsd-5.8.0.par # install
    % par.pl -i http://foo.com/Foo-0.01         # auto-appends archname + perlver
    % par.pl -i cpan://AUTRIJUS/PAR-0.74        # uses CPAN author directory
    % par.pl -u Foo-0.01-i386-freebsd-5.8.0.par # uninstall
    % par.pl -s Foo-0.01-i386-freebsd-5.8.0.par # sign
    % par.pl -v Foo-0.01-i386-freebsd-5.8.0.par # verify

To use F<Hello.pm> from F<./foo.par>:

    % par.pl -A./foo.par -MHello
    % par.pl -A./foo -MHello    # the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % par.pl -Ifoo.par -MHello
    % par.pl -Ifoo -MHello      # ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % par.pl foo.par test.pl    # looks for 'main.pl' by default,
                                # otherwise run 'test.pl'

To make a self-containing script containing a PAR file :

    % par.pl -O./foo.pl foo.par
    % ./foo.pl test.pl          # same as above

To embed the necessary non-core modules and shared objects for PAR's
execution (like C<Zlib>, C<IO>, C<Cwd>, etc), use the B<-b> flag:

    % par.pl -b -O./foo.pl foo.par
    % ./foo.pl test.pl          # runs anywhere with core modules installed

If you also wish to embed I<core> modules along, use the B<-B> flag
instead:

    % par.pl -B -O./foo.pl foo.par
    % ./foo.pl test.pl          # runs anywhere with the perl interpreter

This is particularly useful when making stand-alone binary
executables; see L<pp> for details.

=head1 DESCRIPTION

This stand-alone command offers roughly the same feature as C<perl
-MPAR>, except that it takes the pre-loaded F<.par> files via
C<-Afoo.par> instead of C<-MPAR=foo.par>.

Additionally, it lets you convert a CPAN distribution to a PAR
distribution, as well as manipulate such distributions.  For more
information about PAR distributions, see L<PAR::Dist>.

=head2 Binary PAR loader (L<parl>)

If you have a C compiler, or a pre-built binary package of B<PAR> is
available for your platform, a binary version of B<par.pl> will also be
automatically installed as B<parl>.  You can use it to run F<.par> files:

    # runs script/run.pl in archive, uses its lib/* as libraries
    % parl myapp.par run.pl     # runs run.pl or script/run.pl in myapp.par
    % parl otherapp.pl          # also runs normal perl scripts

However, if the F<.par> archive contains either F<main.pl> or
F<script/main.pl>, it is used instead:

    % parl myapp.par run.pl     # runs main.pl, with 'run.pl' as @ARGV

Finally, the C<-O> option makes a stand-alone binary executable from a
PAR file:

    % parl -B -Omyapp myapp.par
    % ./myapp                   # run it anywhere without perl binaries

With the C<--par-options> flag, generated binaries can act as C<parl>
to pack new binaries:

    % ./myapp --par-options -Omyap2 myapp.par   # identical to ./myapp
    % ./myapp --par-options -Omyap3 myap3.par   # now with different PAR

=head2 Stand-alone executable format

The format for the stand-alone executable is simply concatenating the
following elements:

=over 4

=item * The executable itself

Either in plain-text (F<par.pl>) or native executable format (F<parl>
or F<parl.exe>).

=item * Any number of embedded files

These are typically used for bootstrapping PAR's various XS dependencies.
Each section contains:

=over 4

=item The magic string "C<FILE>"

=item Length of file name in C<pack('N')> format plus 9

=item 8 bytes of hex-encoded CRC32 of file content

=item A single slash ("C</>")

=item The file name (without path)

=item File length in C<pack('N')> format

=item The file's content (not compressed)

=back

=item * One PAR file

This is just a zip file beginning with the magic string "C<PK\003\004>".

=item * Ending section

The pre-computed cache name.  A pack('Z40') string of the value of -T
(--tempcache) or the hash of the file, followed by C<\0CACHE>.  The hash
of the file is calculated with L<Digest::SHA>.

A pack('N') number of the total length of FILE and PAR sections,
followed by a 8-bytes magic string: "C<\012PAR.pm\012>".

=back

=cut


my ($PAR_MAGIC, $par_temp, $progname, @tmpfile, %ModuleCache);
END { if ($ENV{PAR_CLEAN}) {
    require File::Temp;
    require File::Basename;
    require File::Spec;
    my $topdir = File::Basename::dirname($par_temp);
    outs(qq[Removing files in "$par_temp"]);
    File::Find::finddepth(sub { ( -d ) ? rmdir : unlink }, $par_temp);
    rmdir $par_temp;
    # Don't remove topdir because this causes a race with other apps
    # that are trying to start.

    if (-d $par_temp && $^O ne 'MSWin32') {
        # Something went wrong unlinking the temporary directory.  This
        # typically happens on platforms that disallow unlinking shared
        # libraries and executables that are in use. Unlink with a background
        # shell command so the files are no longer in use by this process.
        # Don't do anything on Windows because our parent process will
        # take care of cleaning things up.

        my $tmp = new File::Temp(
            TEMPLATE => 'tmpXXXXX',
            DIR => File::Basename::dirname($topdir),
            SUFFIX => '.cmd',
            UNLINK => 0,
        );
        my $filename = $tmp->filename;

        print $tmp <<"...";
#!/bin/sh
x=1; while [ \$x -lt 10 ]; do
   rm -rf '$par_temp'
   if [ \! -d '$par_temp' ]; then
       break
   fi
   sleep 1
   x=`expr \$x + 1`
done
rm '$filename'
...
        close $tmp;

        chmod 0700, $filename;
        my $cmd = "$filename >/dev/null 2>&1 &";
        system($cmd);
        outs(qq[Spawned background process to perform cleanup: $filename]);
    }
} }

BEGIN {
    Internals::PAR::BOOT() if defined &Internals::PAR::BOOT;
    $PAR_MAGIC = "\nPAR.pm\n";

    eval {

_par_init_env();

my $quiet = !$ENV{PAR_DEBUG};

# fix $progname if invoked from PATH
my %Config = (
    path_sep    => ($^O =~ /^MSWin/ ? ';' : ':'),
    _exe        => ($^O =~ /^(?:MSWin|OS2|cygwin)/ ? '.exe' : ''),
    _delim      => ($^O =~ /^MSWin|OS2/ ? '\\' : '/'),
);

_set_progname();
_set_par_temp();

# Magic string checking and extracting bundled modules {{{
my ($start_pos, $data_pos);
{
    local $SIG{__WARN__} = sub {};

    # Check file type, get start of data section {{{
    open _FH, '<:raw', $progname or last;

    # Search for the "\nPAR.pm\n signature backward from the end of the file
    my $buf;
    my $size = -s $progname;
    my $chunk_size = 64 * 1024;
    my $magic_pos;

    if ($size <= $chunk_size) {
        $magic_pos = 0;
    } elsif ((my $m = $size % $chunk_size) > 0) {
        $magic_pos = $size - $m;
    } else {
        $magic_pos = $size - $chunk_size;
    }
    # in any case, $magic_pos is a multiple of $chunk_size

    while ($magic_pos >= 0) {
        seek _FH, $magic_pos, 0;
        read _FH, $buf, $chunk_size + length($PAR_MAGIC);
        if ((my $i = rindex($buf, $PAR_MAGIC)) >= 0) {
            $magic_pos += $i;
            last;
        }
        $magic_pos -= $chunk_size;
    }
    last if $magic_pos < 0;

    # Seek 4 bytes backward from the signature to get the offset of the
    # first embedded FILE, then seek to it
    seek _FH, $magic_pos - 4, 0;
    read _FH, $buf, 4;
    seek _FH, $magic_pos - 4 - unpack("N", $buf), 0;
    $data_pos = tell _FH;

    # }}}

    # Extracting each file into memory {{{
    my %require_list;
    read _FH, $buf, 4;                           # read the first "FILE"
    while ($buf eq "FILE") {
        read _FH, $buf, 4;
        read _FH, $buf, unpack("N", $buf);

        my $fullname = $buf;
        outs(qq[Unpacking FILE "$fullname"...]);
        my $crc = ( $fullname =~ s|^([a-f\d]{8})/|| ) ? $1 : undef;
        my ($basename, $ext) = ($buf =~ m|(?:.*/)?(.*)(\..*)|);

        read _FH, $buf, 4;
        read _FH, $buf, unpack("N", $buf);

        if (defined($ext) and $ext !~ /\.(?:pm|pl|ix|al)$/i) {
            my $filename = _save_as("$crc$ext", $buf, 0755);
            $PAR::Heavy::FullCache{$fullname} = $filename;
            $PAR::Heavy::FullCache{$filename} = $fullname;
        }
        elsif ( $fullname =~ m|^/?shlib/| and defined $ENV{PAR_TEMP} ) {
            my $filename = _save_as("$basename$ext", $buf, 0755);
            outs("SHLIB: $filename\n");
        }
        else {
            $require_list{$fullname} =
            $ModuleCache{$fullname} = {
                buf => $buf,
                crc => $crc,
                name => $fullname,
            };
        }
        read _FH, $buf, 4;
    }
    # }}}

    local @INC = (sub {
        my ($self, $module) = @_;

        return if ref $module or !$module;

        my $info = delete $require_list{$module} or return;

        $INC{$module} = "/loader/$info/$module";

        if ($ENV{PAR_CLEAN} and defined(&IO::File::new)) {
            my $fh = IO::File->new_tmpfile or die "Can't create temp file: $!";
            $fh->binmode();
            $fh->print($info->{buf});
            $fh->seek(0, 0);
            return $fh;
        }
        else {
            my $filename = _save_as("$info->{crc}.pm", $info->{buf});

            open my $fh, '<:raw', $filename or die qq[Can't read "$filename": $!];
            return $fh;
        }

        die "Bootstrapping failed: can't find module $module!";
    }, @INC);

    # Now load all bundled files {{{

    # initialize shared object processing
    require XSLoader;
    require PAR::Heavy;
    require Carp::Heavy;
    require Exporter::Heavy;
    PAR::Heavy::_init_dynaloader();

    # now let's try getting helper modules from within
    require IO::File;

    # load rest of the group in
    while (my $filename = (sort keys %require_list)[0]) {
        #local $INC{'Cwd.pm'} = __FILE__ if $^O ne 'MSWin32';
        unless ($INC{$filename} or $filename =~ /BSDPAN/) {
            # require modules, do other executable files
            if ($filename =~ /\.pmc?$/i) {
                require $filename;
            }
            else {
                # Skip ActiveState's sitecustomize.pl file:
                do $filename unless $filename =~ /sitecustomize\.pl$/;
            }
        }
        delete $require_list{$filename};
    }

    # }}}

    last unless $buf eq "PK\003\004";
    $start_pos = (tell _FH) - 4;                # start of zip
}
# }}}

# Argument processing {{{
my @par_args;
my ($out, $bundle, $logfh, $cache_name);

delete $ENV{PAR_APP_REUSE}; # sanitize (REUSE may be a security problem)

$quiet = 0 unless $ENV{PAR_DEBUG};
# Don't swallow arguments for compiled executables without --par-options
if (!$start_pos or ($ARGV[0] eq '--par-options' && shift)) {
    my %dist_cmd = qw(
        p   blib_to_par
        i   install_par
        u   uninstall_par
        s   sign_par
        v   verify_par
    );

    # if the app is invoked as "appname --par-options --reuse PROGRAM @PROG_ARGV",
    # use the app to run the given perl code instead of anything from the
    # app itself (but still set up the normal app environment and @INC)
    if (@ARGV and $ARGV[0] eq '--reuse') {
        shift @ARGV;
        $ENV{PAR_APP_REUSE} = shift @ARGV;
    }
    else { # normal parl behaviour

        my @add_to_inc;
        while (@ARGV) {
            $ARGV[0] =~ /^-([AIMOBLbqpiusTv])(.*)/ or last;

            if ($1 eq 'I') {
                push @add_to_inc, $2;
            }
            elsif ($1 eq 'M') {
                eval "use $2";
            }
            elsif ($1 eq 'A') {
                unshift @par_args, $2;
            }
            elsif ($1 eq 'O') {
                $out = $2;
            }
            elsif ($1 eq 'b') {
                $bundle = 'site';
            }
            elsif ($1 eq 'B') {
                $bundle = 'all';
            }
            elsif ($1 eq 'q') {
                $quiet = 1;
            }
            elsif ($1 eq 'L') {
                open $logfh, ">>", $2 or die qq[Can't open log file "$2": $!];
            }
            elsif ($1 eq 'T') {
                $cache_name = $2;
            }

            shift(@ARGV);

            if (my $cmd = $dist_cmd{$1}) {
                delete $ENV{'PAR_TEMP'};
                init_inc();
                require PAR::Dist;
                &{"PAR::Dist::$cmd"}() unless @ARGV;
                &{"PAR::Dist::$cmd"}($_) for @ARGV;
                exit;
            }
        }

        unshift @INC, @add_to_inc;
    }
}

# XXX -- add --par-debug support!

# }}}

# Output mode (-O) handling {{{
if ($out) {
    {
        #local $INC{'Cwd.pm'} = __FILE__ if $^O ne 'MSWin32';
        require IO::File;
        require Archive::Zip;
        require Digest::SHA;
    }

    my $par = shift(@ARGV);
    my $zip;


    if (defined $par) {
        open my $fh, '<:raw', $par or die qq[Can't find par file "$par": $!];
        bless($fh, 'IO::File');

        $zip = Archive::Zip->new;
        ( $zip->readFromFileHandle($fh, $par) == Archive::Zip::AZ_OK() )
            or die qq[Error reading zip archive "$par"];
    }


    my %env = do {
        if ($zip and my $meta = $zip->contents('META.yml')) {
            $meta =~ s/.*^par:$//ms;
            $meta =~ s/^\S.*//ms;
            $meta =~ /^  ([^:]+): (.+)$/mg;
        }
    };

    # Open input and output files {{{

    if (defined $par) {
        open my $ph, '<:raw', $par or die qq[Can't read par file "$par": $!];
        my $buf;
        read $ph, $buf, 4;
        die qq["$par" is not a par file] unless $buf eq "PK\003\004";
        close $ph;
    }

    CreatePath($out) ;

    my $fh = IO::File->new(
        $out,
        IO::File::O_CREAT() | IO::File::O_WRONLY() | IO::File::O_TRUNC(),
        0777,
    ) or die qq[Can't create file "$out": $!];
    $fh->binmode();

    seek _FH, 0, 0;

    my $loader;
    if (defined $data_pos) {
        read _FH, $loader, $data_pos;
    } else {
        local $/ = undef;
        $loader = <_FH>;
    }

    if (!$ENV{PAR_VERBATIM} and $loader =~ /^(?:#!|\@rem)/) {
        require PAR::Filter::PodStrip;
        PAR::Filter::PodStrip->apply(\$loader, $0);
    }
    foreach my $key (sort keys %env) {
        my $val = $env{$key} or next;
        $val = eval $val if $val =~ /^['"]/;
        my $magic = "__ENV_PAR_" . uc($key) . "__";
        my $set = "PAR_" . uc($key) . "=$val";
        $loader =~ s{$magic( +)}{
            $magic . $set . (' ' x (length($1) - length($set)))
        }eg;
    }
    $fh->print($loader);
    # }}}

    # Write bundled modules {{{
    if ($bundle) {
        require PAR::Heavy;
        PAR::Heavy::_init_dynaloader();

        init_inc();

        require_modules();

        my @inc = grep { !/BSDPAN/ }
                       grep {
                           ($bundle ne 'site') or
                           ($_ ne $Config::Config{archlibexp} and
                           $_ ne $Config::Config{privlibexp});
                       } @INC;

        # normalize paths (remove trailing or multiple consecutive slashes)
        s|/+|/|g, s|/$|| foreach @inc;

        # Now determine the files loaded above by require_modules():
        # Perl source files are found in values %INC and DLLs are
        # found in @DynaLoader::dl_shared_objects.
        my %files;
        $files{$_}++ for @DynaLoader::dl_shared_objects, values %INC;

        my $lib_ext = $Config::Config{lib_ext};         # XXX lib_ext vs dlext ?
        my %written;

        foreach my $key (sort keys %files) {
            my ($file, $name);

            if (defined(my $fc = $PAR::Heavy::FullCache{$key})) {
                ($file, $name) = ($key, $fc);
            }
            else {
                foreach my $dir (@inc) {
                    if ($key =~ m|^\Q$dir\E/(.*)$|i) {
                        ($file, $name) = ($key, $1);
                        last;
                    }
                    if ($key =~ m|^/loader/[^/]+/(.*)$|) {
                        if (my $ref = $ModuleCache{$1}) {
                            ($file, $name) = ($ref, $1);
                            last;
                        }
                        if (-f "$dir/$1") {
                            ($file, $name) = ("$dir/$1", $1);
                            last;
                        }
                    }
                }
            }
            # There are legitimate reasons why we couldn't find $name and $file for a $key:
            # - cperl has e.g. $INC{"XSLoader.pm"} = "XSLoader.c",
            #   $INC{"DynaLoader.pm"}' = "dlboot_c.PL"
            next unless defined $name;

            next if $written{$name}++;
            next if !ref($file) and $file =~ /\.\Q$lib_ext\E$/i;

            outs(sprintf(qq[Packing FILE "%s"...], ref $file ? $file->{name} : $file));
            my $content;
            if (ref($file)) {
                $content = $file->{buf};
            }
            else {
                local $/ = undef;
                open my $fh, '<:raw', $file or die qq[Can't read "$file": $!];
                $content = <$fh>;
                close $fh;

                PAR::Filter::PodStrip->apply(\$content, "<embedded>/$name")
                    if !$ENV{PAR_VERBATIM} and $name =~ /\.(?:pm|ix|al)$/i;

                PAR::Filter::PatchContent->new->apply(\$content, $file, $name);
            }

            $fh->print("FILE",
                       pack('N', length($name) + 9),
                       sprintf("%08x/%s", Archive::Zip::computeCRC32($content), $name),
                       pack('N', length($content)),
                       $content);
            outs(qq[Written as "$name"]);
        }
    }
    # }}}

    # Now write out the PAR and magic strings {{{
    $zip->writeToFileHandle($fh) if $zip;

    $cache_name = substr $cache_name, 0, 40;
    if (!$cache_name and my $mtime = (stat($out))[9]) {
        my $ctx = Digest::SHA->new(1);
        open my $fh, "<:raw", $out;
        $ctx->addfile($fh);
        close $fh;

        $cache_name = $ctx->hexdigest;
    }
    $cache_name .= "\0" x (41 - length $cache_name);
    $cache_name .= "CACHE";
    $fh->print($cache_name);
    $fh->print(pack('N', $fh->tell - length($loader)));
    $fh->print($PAR_MAGIC);
    $fh->close;
    chmod 0755, $out;
    # }}}

    exit;
}
# }}}

# Prepare $progname into PAR file cache {{{
{
    last unless defined $start_pos;

    _fix_progname();

    # Now load the PAR file and put it into PAR::LibCache {{{
    require PAR;
    PAR::Heavy::_init_dynaloader();


    {
        #local $INC{'Cwd.pm'} = __FILE__ if $^O ne 'MSWin32';
        require File::Find;
        require Archive::Zip;
    }

    my $fh = IO::File->new;                             # Archive::Zip operates on an IO::Handle
    $fh->fdopen(fileno(_FH), 'r') or die qq[fdopen() failed: $!];

    # Temporarily increase the chunk size for Archive::Zip so that it will find the EOCD
    # even if lots of stuff has been appended to the pp'ed exe (e.g. by OSX codesign).
    Archive::Zip::setChunkSize(-s _FH);
    my $zip = Archive::Zip->new;
    ( $zip->readFromFileHandle($fh, $progname) == Archive::Zip::AZ_OK() )
        or die qq[Error reading zip archive "$progname"];
    Archive::Zip::setChunkSize(64 * 1024);

    push @PAR::LibCache, $zip;
    $PAR::LibCache{$progname} = $zip;

    $quiet = !$ENV{PAR_DEBUG};
    outs(qq[\$ENV{PAR_TEMP} = "$ENV{PAR_TEMP}"]);

    if (defined $ENV{PAR_TEMP}) { # should be set at this point!
        foreach my $member ( $zip->members ) {
            next if $member->isDirectory;
            my $member_name = $member->fileName;
            next unless $member_name =~ m{
                ^
                /?shlib/
                (?:$Config::Config{version}/)?
                (?:$Config::Config{archname}/)?
                ([^/]+)
                $
            }x;
            my $extract_name = $1;
            my $dest_name = File::Spec->catfile($ENV{PAR_TEMP}, $extract_name);
            if (-f $dest_name && -s _ == $member->uncompressedSize()) {
                outs(qq[Skipping "$member_name" since it already exists at "$dest_name"]);
            } else {
                outs(qq[Extracting "$member_name" to "$dest_name"]);
                $member->extractToFileNamed($dest_name);
                chmod(0555, $dest_name) if $^O eq "hpux";
            }
        }
    }
    # }}}
}
# }}}

# If there's no main.pl to run, show usage {{{
unless ($PAR::LibCache{$progname}) {
    die << "." unless @ARGV;
Usage: $0 [ -Alib.par ] [ -Idir ] [ -Mmodule ] [ src.par ] [ program.pl ]
       $0 [ -B|-b ] [-Ooutfile] src.par
.
    $ENV{PAR_PROGNAME} = $progname = $0 = shift(@ARGV);
}
# }}}

sub CreatePath {
    my ($name) = @_;

    require File::Basename;
    my ($basename, $path, $ext) = File::Basename::fileparse($name, ('\..*'));

    require File::Path;

    File::Path::mkpath($path) unless(-e $path); # mkpath dies with error
}

sub require_modules {

    require lib;
    require DynaLoader;
    require integer;
    require strict;
    require warnings;
    require vars;
    require Carp;
    require Carp::Heavy;
    require Errno;
    require Exporter::Heavy;
    require Exporter;
    require Fcntl;
    require File::Temp;
    require File::Spec;
    require XSLoader;
    require Config;
    require IO::Handle;
    require IO::File;
    require Compress::Zlib;
    require Archive::Zip;
    require Digest::SHA;
    require PAR;
    require PAR::Heavy;
    require PAR::Dist;
    require PAR::Filter::PodStrip;
    require PAR::Filter::PatchContent;
    require attributes;
    eval { require Cwd };
    eval { require Win32 };
    eval { require Scalar::Util };
    eval { require Archive::Unzip::Burst };
    eval { require Tie::Hash::NamedCapture };
    eval { require PerlIO; require PerlIO::scalar };
    eval { require utf8 };
}

# The C version of this code appears in myldr/mktmpdir.c
# This code also lives in PAR::SetupTemp as set_par_temp_env!
sub _set_par_temp {
    if (defined $ENV{PAR_TEMP} and $ENV{PAR_TEMP} =~ /(.+)/) {
        $par_temp = $1;
        return;
    }

    foreach my $path (
        (map $ENV{$_}, qw( PAR_TMPDIR TMPDIR TEMPDIR TEMP TMP )),
        qw( C:\\TEMP /tmp . )
    ) {
        next unless defined $path and -d $path and -w $path;
        my $username;
        my $pwuid;
        # does not work everywhere:
        eval {($pwuid) = getpwuid($>) if defined $>;};

        if ( defined(&Win32::LoginName) ) {
            $username = &Win32::LoginName;
        }
        elsif (defined $pwuid) {
            $username = $pwuid;
        }
        else {
            $username = $ENV{USERNAME} || $ENV{USER} || 'SYSTEM';
        }
        $username =~ s/\W/_/g;

        my $stmpdir = "$path$Config{_delim}par-".unpack("H*", $username);
        mkdir $stmpdir, 0755;
        if (!$ENV{PAR_CLEAN} and my $mtime = (stat($progname))[9]) {
            open my $fh, "<:raw", $progname or die qq[Can't read "$progname": $!];
            seek $fh, -18, 2;
            my $buf;
            read $fh, $buf, 6;
            if ($buf eq "\0CACHE") {
                seek $fh, -58, 2;
                read $fh, $buf, 41;
                $buf =~ s/\0//g;
                $stmpdir .= "$Config{_delim}cache-$buf";
            }
            else {
                my $digest = eval
                {
                    require Digest::SHA;
                    my $ctx = Digest::SHA->new(1);
                    open my $fh, "<:raw", $progname or die qq[Can't read "$progname": $!];
                    $ctx->addfile($fh);
                    close($fh);
                    $ctx->hexdigest;
                } || $mtime;

                $stmpdir .= "$Config{_delim}cache-$digest";
            }
            close($fh);
        }
        else {
            $ENV{PAR_CLEAN} = 1;
            $stmpdir .= "$Config{_delim}temp-$$";
        }

        $ENV{PAR_TEMP} = $stmpdir;
        mkdir $stmpdir, 0755;
        last;
    }

    $par_temp = $1 if $ENV{PAR_TEMP} and $ENV{PAR_TEMP} =~ /(.+)/;
}


# check if $name (relative to $par_temp) already exists;
# if not, create a file with a unique temporary name,
# fill it with $contents, set its file mode to $mode if present;
# finaly rename it to $name;
# in any case return the absolute filename
sub _save_as {
    my ($name, $contents, $mode) = @_;

    my $fullname = "$par_temp/$name";
    unless (-e $fullname) {
        my $tempname = "$fullname.$$";

        open my $fh, '>:raw', $tempname or die qq[Can't write "$tempname": $!];
        print $fh $contents;
        close $fh;
        chmod $mode, $tempname if defined $mode;

        rename($tempname, $fullname) or unlink($tempname);
        # NOTE: The rename() error presumably is something like ETXTBSY
        # (scenario: another process was faster at extraction $fullname
        # than us and is already using it in some way); anyway,
        # let's assume $fullname is "good" and clean up our copy.
    }

    return $fullname;
}

# same code lives in PAR::SetupProgname::set_progname
sub _set_progname {
    if (defined $ENV{PAR_PROGNAME} and $ENV{PAR_PROGNAME} =~ /(.+)/) {
        $progname = $1;
    }

    $progname ||= $0;

    if ($ENV{PAR_TEMP} and index($progname, $ENV{PAR_TEMP}) >= 0) {
        $progname = substr($progname, rindex($progname, $Config{_delim}) + 1);
    }

    if (!$ENV{PAR_PROGNAME} or index($progname, $Config{_delim}) >= 0) {
        if (open my $fh, '<', $progname) {
            return if -s $fh;
        }
        if (-s "$progname$Config{_exe}") {
            $progname .= $Config{_exe};
            return;
        }
    }

    foreach my $dir (split /\Q$Config{path_sep}\E/, $ENV{PATH}) {
        next if exists $ENV{PAR_TEMP} and $dir eq $ENV{PAR_TEMP};
        $dir =~ s/\Q$Config{_delim}\E$//;
        (($progname = "$dir$Config{_delim}$progname$Config{_exe}"), last)
            if -s "$dir$Config{_delim}$progname$Config{_exe}";
        (($progname = "$dir$Config{_delim}$progname"), last)
            if -s "$dir$Config{_delim}$progname";
    }
}

sub _fix_progname {
    $0 = $progname ||= $ENV{PAR_PROGNAME};
    if (index($progname, $Config{_delim}) < 0) {
        $progname = ".$Config{_delim}$progname";
    }

    # XXX - hack to make PWD work
    my $pwd = (defined &Cwd::getcwd) ? Cwd::getcwd()
                : ((defined &Win32::GetCwd) ? Win32::GetCwd() : `pwd`);
    chomp($pwd);
    $progname =~ s/^(?=\.\.?\Q$Config{_delim}\E)/$pwd$Config{_delim}/;

    $ENV{PAR_PROGNAME} = $progname;
}

sub _par_init_env {
    if ( $ENV{PAR_INITIALIZED}++ == 1 ) {
        return;
    } else {
        $ENV{PAR_INITIALIZED} = 2;
    }

    for (qw( SPAWNED TEMP CLEAN DEBUG CACHE PROGNAME ) ) {
        delete $ENV{'PAR_'.$_};
    }
    for (qw/ TMPDIR TEMP CLEAN DEBUG /) {
        $ENV{'PAR_'.$_} = $ENV{'PAR_GLOBAL_'.$_} if exists $ENV{'PAR_GLOBAL_'.$_};
    }

    my $par_clean = "__ENV_PAR_CLEAN__               ";

    if ($ENV{PAR_TEMP}) {
        delete $ENV{PAR_CLEAN};
    }
    elsif (!exists $ENV{PAR_GLOBAL_CLEAN}) {
        my $value = substr($par_clean, 12 + length("CLEAN"));
        $ENV{PAR_CLEAN} = $1 if $value =~ /^PAR_CLEAN=(\S+)/;
    }
}

sub outs {
    return if $quiet;
    if ($logfh) {
        print $logfh "@_\n";
    }
    else {
        print "@_\n";
    }
}

sub init_inc {
    require Config;
    push @INC, grep defined, map $Config::Config{$_}, qw(
        archlibexp privlibexp sitearchexp sitelibexp
        vendorarchexp vendorlibexp
    );
}

########################################################################
# The main package for script execution

package main;

require PAR;
unshift @INC, \&PAR::find_par;
PAR->import(@par_args);

die qq[par.pl: Can't open perl script "$progname": No such file or directory\n]
    unless -e $progname;

do $progname;
CORE::exit($1) if ($@ =~/^_TK_EXIT_\((\d+)\)/);
die $@ if $@;

};

$::__ERROR = $@ if $@;
}

CORE::exit($1) if ($::__ERROR =~/^_TK_EXIT_\((\d+)\)/);
die $::__ERROR if $::__ERROR;

1;

=head1 SEE ALSO

L<PAR>, L<PAR::Dist>, L<parl>, L<pp>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>,
Steffen Mueller E<lt>smueller@cpan.orgE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par-packer@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2002-2009 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

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

 __END__
