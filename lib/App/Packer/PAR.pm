package App::Packer::PAR;

use strict;
use warnings;
use vars qw($VERSION);
use Config;

$VERSION = '0.91';

sub new {
    my ($type, %args) = @_;

    my $class = ref $type || $type;
    my $self = bless {}, $class;

    # apply default values for frontend/backend
    $args{frontend} ||= 'App::Packer::Frontend::ModuleInfo';
    $args{backend}  ||= 'App::Packer::Backend::DemoPack';

    # automatically require default frontend/backend
    if ($args{frontend} eq 'App::Packer::Frontend::ModuleInfo') {
        require App::Packer::Frontend::ModuleInfo;
    }
    else {
        _require($args{frontend});
    }

    if ($args{backend} eq 'App::Packer::Backend::DemoPack') {
        require App::Packer::Backend::DemoPack;
    }
    else {
        _require($args{backend});
    }

    my $fe = $self->{FRONTEND} =
      ($args{frontend}->can('new')) ? $args{frontend}->new : $args{frontend};

    my $be = $self->{BACKEND} =
      ($args{backend}->can('new')) ? $args{backend}->new : $args{backend};

    $self->_set_args(%args);
    $self->_set_options(%args);

    $be->set_front($fe) if ($be->can('set_front'));

    return $self;
}

sub _set_options {
    my ($self, %args) = @_;

    my $fe = $self->frontend;
    my $be = $self->backend;

    my $frontopts = $args{frontopts} || $args{opts} || undef;
    my $backopts  = $args{backopts}  || $args{opts} || undef;

    $fe->set_options(%$frontopts) if ($fe->can('set_options') and $frontopts);
    $be->set_options(%$backopts)  if ($be->can('set_options') and $backopts);
}

sub _set_args {
    my ($self, %args) = @_;

    my $fe = $self->frontend;
    my $be = $self->backend;

    my $frontargs = $args{frontargs} || $args{args} || undef;
    my $backargs  = $args{backargs}  || $args{args} || undef;

    return if (!$frontargs and !$backargs);

    $fe->set_args(@$frontargs) if ($fe->can('set_args') and $frontargs);
    $be->set_args(@$backargs)  if ($be->can('set_args') and $backargs);
}

sub set_file {
    my $self = shift;
    my $file = shift;

    warn("File not found '$file'"), return unless -f $file;

    $self->backend->set_file($file);

    return 1;
}

sub go {
    my ($self) = @_;

    my $fe = $self->frontend;
    my $be = $self->backend;

    $fe->go if $fe->can('go');
    $be->go if $be->can('go');
}

sub generate_pack {
    my ($self, %opt) = @_;

    my $be = $self->backend;
    $be->generate_pack(%opt);
}

sub run_pack {
    my ($self, %opt) = @_;

    my $be = $self->backend;
    $be->run_pack(%opt);
}

sub add_manifest {
    my ($self) = @_;

    my $be = $self->backend;
    return $be->add_manifest;
}

sub pack_manifest {
    my ($self) = @_;

    my $be = $self->backend;
    return $be->pack_manifest;
}

sub write {
    my $self = shift;
    my $exe  = shift;
    my $ret  = 1;

    # attach exe extension
    $exe .= $Config{_exe} unless $exe =~ m/$Config{_exe}$/i;

    # write file
    $self->frontend->calculate_info;
    my $files = $self->frontend->get_files;
    $ret &= $files ? 1 : 0;
    $ret &= $self->backend->set_files(%$files);
    $ret &= $self->backend->write($exe);

    chmod 0755, $exe if $ret;

    $ret ? return $exe : return;
}

sub set_options {
    my $self = shift;
    my %args = @_;

    if (exists $args{frontend}) {
        $self->frontend->set_options(%{ $args{frontend} });
    }

    if (exists $args{backend}) {
        $self->backend->set_options(%{ $args{backend} });
    }
}

sub add_back_options {
    my ($self, %opt) = @_;
    $self->backend->add_options(%opt);
}

sub add_front_options {
    my ($self, %opt) = @_;
    $self->frontend->add_options(%opt);
}

sub frontend { $_[0]->{FRONTEND} or die "No frontend available" }
sub backend  { $_[0]->{BACKEND}  or die "No backend available" }

sub _require {
    my ($text) = @_;
    $text =~ s{::}{/}g;
    require "$text.pm";
}

1;

__END__

=head1 NAME

App::Packer::PAR - Pack applications in a single executable file

=head1 DESCRIPTION

This module is a modified version of B<App::Packer>, temporarily shipped
with B<PAR> until it is merged into newer versions of B<App::Packer>.

=head1 SEE ALSO

See L<App::Packer> for the programming interface.

=head1 AUTHOR

Code modifications by Edward S. Peschko.  This documentation by Audrey Tang.

Based on the work of Mattia Barbon E<lt>mbarbon@dsi.unive.itE<gt>.

=head1 COPYRIGHT

Copyright 2004-2009 by Edward S. Peschko, Audrey Tang and Mattia Barbon.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut

# local variables:
# mode: cperl
# end:
