#line 1
package Module::Install::PAR;

use strict;
use Module::Install::Base ();

use vars qw{$VERSION @ISA $ISCORE};
BEGIN {
	$VERSION = '1.14';
	@ISA     = 'Module::Install::Base';
	$ISCORE  = 1;
}

#line 74

sub par_base {
    my ($self, $base, $file) = @_;
    my $class     = ref($self);
    my $inc_class = join('::', @{$self->_top}{qw(prefix name)});
    my $ftp_base;

    if ( defined $base and length $base ) {
        if ( $base =~ m!^(([A-Z])[A-Z])[-_A-Z]+\Z! ) {
            $self->{mailto} = "$base\@cpan.org";
            $ftp_base = "ftp://ftp.cpan.org/pub/CPAN/authors/id/$2/$1/$base";
            $base     = "http://www.cpan.org/authors/id/$2/$1/$base";
        } elsif ( $base !~ m!^(\w+)://! ) {
            die "Cannot recognize path '$base'; please specify an URL or CPAN ID";
        }
        $base     .= '/' unless $base     =~ m!/\Z!;
        $ftp_base .= '/' unless $ftp_base =~ m!/\Z!;
    }

    require Config;
    my $suffix = "$Config::Config{archname}-$Config::Config{version}.par";

    unless ( $file ||= $self->{file} ) {
        my $name    = $self->name    or return;
        my $version = $self->version or return;
        $name =~ s!::!-!g;
        $self->{file} = $file = "$name-$version-$suffix";
    }

    my $perl = $^X;
    $perl = Win32::GetShortPathName($perl)
        if $perl =~ / / and defined &Win32::GetShortPathName;

    $self->preamble(<<"END_MAKEFILE") if $base;
# --- $class section:

all ::
\t\$(NOECHO) $perl "-M$inc_class" -e "extract_par(q($file))"

END_MAKEFILE

    $self->postamble(<<"END_MAKEFILE");
# --- $class section:

$file: all test
\t\$(NOECHO) \$(PERL) "-M$inc_class" -e "make_par(q($file))"

par :: $file
\t\$(NOECHO) \$(NOOP)

par-upload :: $file
\tcpan-upload -verbose $file

END_MAKEFILE

    $self->{url}     = $base;
    $self->{ftp_url} = $ftp_base;
    $self->{suffix}  = $suffix;

    return $self;
}

#line 161

sub fetch_par {
    my ($self, $url, $file, $quiet) = @_;
    $url = '' if not defined $url;
    $file = '' if not defined $file;
    
    $url = $self->{url} || $self->par_base($url)->{url};
    my $ftp_url = $self->{ftp_url};
    $file ||= $self->{file};

    return $file if -f $file or $self->get_file(
        url     => "$url$file",
        ftp_url => "$ftp_url$file"
    );

    require Config;
    print <<"END_MESSAGE" if $self->{mailto} and ! $quiet;
*** No installation package available for your architecture.
However, you may wish to generate one with '$Config::Config{make} par' and send
it to <$self->{mailto}>, so other people on the same platform
can benefit from it.
*** Proceeding with normal installation...
END_MESSAGE
    return;
}

#line 197

sub extract_par {
    my ($self, $file) = @_;
    return unless -f $file;

    if ( eval { require Archive::Zip; 1 } ) {
        my $zip = Archive::Zip->new;
        return unless $zip->read($file) == Archive::Zip::AZ_OK()
                  and $zip->extractTree('', 'blib/') == Archive::Zip::AZ_OK();
    } elsif ( $self->can_run('unzip') ) {
        return if system( unzip => $file, qw(-d blib) );
    }
    else {
        die <<'HERE';
Could not extract .par archive because neither Archive::Zip nor a
working 'unzip' binary are available. Please consider installing
Archive::Zip.
HERE
    }

    local *PM_TO_BLIB;
    open PM_TO_BLIB, '> pm_to_blib' or die $!;
    close PM_TO_BLIB or die $!;

    return 1;
}

#line 243

sub make_par {
    my ($self, $file) = @_;
    unlink $file if -f $file;

    unless ( eval { require PAR::Dist; PAR::Dist->VERSION(0.03) } ) {
        warn "Please install PAR::Dist 0.03 or above first.";
        return;
    }

    return PAR::Dist::blib_to_par( dist => $file );
}

1;

#line 274
