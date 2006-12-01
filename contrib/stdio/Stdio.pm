##==============================================================================
## Tk::Stdio - capture program standard output and standard error,
##             accept standard input
##==============================================================================
## Tk::Stdio is based on:
##
## Tk::Stderr - capture program standard error output
##==============================================================================
require 5.006;

package Tk::Stdio;
use strict;
use warnings;
use vars qw($VERSION @ISA);
($VERSION) = q$Revision: 1.0 $ =~ /Revision:\s+(\S+)/ or $VERSION = "0.0";
use base qw(Tk::Derived Tk::MainWindow);

use Tk::Text;
use Tk::Frame;

=pod

=head1 NAME

Tk::Stdio - capture standard output and error,
            accept standard input,
            display in separate window

=head1 SYNOPSIS

    use Tk::Stdio;

    $mw = MainWindow->new->InitStdio;
    print "something\n";    ## goes to standard IO window
    print STDERR 'stuff';   ## likewise
	warn 'eek!';            ## likewise
    my $input = <STDIN>;    ## keyboard entry is in standard IO window
    my $char = getc;        ## likewise

=head1 DESCRIPTION

This module captures the standard output or error of a program and redirects it to a read
only text widget, which doesn't appear until necessary. When it does appear, the
user can close it; it'll appear again when there is more output. Standard input can be
entered in the widget, which becomes temporarily writable.

=cut

$Tk::Stdio::first_char = '1.0';    # 'line.char' set in READLINE or GETC

##==============================================================================
## Populate
##==============================================================================
sub Populate {
    my ( $mw, $args ) = @_;
    my $private = $mw->privateData;
    $private->{ReferenceCount} = 0;
    $private->{Enabled}        = 0;

    $mw->SUPER::Populate($args);

    $mw->withdraw;
    $mw->protocol( WM_DELETE_WINDOW => [ $mw => 'withdraw' ] );

    my $f = $mw->Frame( Name => 'stderr_frame', )->pack( -fill => 'both', -expand => 1 );

    my $text = $f->Scrolled( 'Text',
                             -wrap             => 'char',
                             -scrollbars       => 'oe',
                             -state            => 'disabled',
                             -fg               => 'white',
                             -bg               => 'black',
                             -insertbackground => 'white',
                           )->pack( -fill => 'both', -expand => 1 );

    $text->bind( '<Button>', sub { $text->SetCursor('end') } );
    $text->bind( '<Up>',     sub { $text->SetCursor('end') } );
    $text->bind( '<Down>',   sub { $text->SetCursor('end') } );
    $text->bind( '<Next>',   sub { $text->SetCursor('end') } );
    $text->bind( '<Prior>',  sub { $text->SetCursor('end') } );
    $text->bind( '<Home>',   sub { $text->SetCursor($Tk::Stdio::first_char) } );
    $text->bind( 'Tk::Text', '<Left>',
                 sub {
                     my $cursor = $text->index('insert');
                     $text->SetCursor("$cursor -1 chars") if $cursor > $Tk::Stdio::first_char;
                 }
               );
    $text->bind( 'Tk::Text', '<Return>',
                 sub { $text->insert( 'end', "\n" ); $text->SetCursor('end'); }
               );

    $mw->Advertise( 'text' => $text );

    $mw->ConfigSpecs( '-title' => [ qw/METHOD title Title/, 'Standard IO' ], );

    $mw->Redirect(1);

    return $mw;
} ## end sub Populate

##==============================================================================
## Redirect
##==============================================================================
sub Redirect {
    my ( $mw, $boolean ) = @_;
    my $private = $mw->privateData;
    my $old     = $private->{Enabled};

    if ( $old && !$boolean ) {
        untie *STDIN;
        untie *STDOUT;
        untie *STDERR;
        $SIG{__WARN__} = 'DEFAULT';
    }
    elsif ( !$old && $boolean ) {
        tie *STDIN,  'Tk::Stdio::Handle', $mw;
        tie *STDOUT, 'Tk::Stdio::Handle', $mw;
        tie *STDERR, 'Tk::Stdio::Handle', $mw;
        $SIG{__WARN__} = sub { print STDERR @_ };
    }
    $private->{Enabled} = $boolean;
    return $old;
}

##==============================================================================
## DecrementReferenceCount
##==============================================================================
sub DecrementReferenceCount {
    my ($mw) = @_;
    my $private = $mw->privateData;

    if ( --$private->{ReferenceCount} <= 0 ) {
        $mw->destroy;
    }
}

##==============================================================================
## IncrementReferenceCount
##==============================================================================
sub IncrementReferenceCount {
    my ($mw) = @_;
    my $private = $mw->privateData;

    ++$private->{ReferenceCount};
}

=pod

=head1 METHODS

These are actually added to the MainWindow class.

=over 4

=item I<$mw>->InitStdio;

The first time this method called, it does the following things:

=over 4

=item o

Creates a MainWindow holding a read-only scrollable text widget, and withdraws
this window until it's actually needed.

=item o

Ties STDOUT, STDERR and STDIN to a special handle that adds the output to this text widget.

=item o

Installs a C<< $SIG{__WARN__} >> handler that redirects the output from B<warn>
to this window as well (by printing it to STDERR).

=back

On the remaining calls, it:

=over 4

=item o

Increments a reference count of "other" MainWindows.

=item o

Installs an OnDestroy handler that decrements this reference count, so that it
can detect when it's the only MainWindow left and destroy itself.

=back

=cut

package MainWindow;
use strict;
use warnings;

my $io_window;

##==============================================================================
## InitStdio
##==============================================================================
sub InitStdio {
    my ( $mw, $title ) = @_;

    unless ( defined $io_window ) {
        $io_window = Tk::Stdio->new;
        $io_window->title($title) if defined $title;
    }
    $io_window->IncrementReferenceCount;
    $mw->OnDestroy( [ 'DecrementReferenceCount' => $io_window ] );
    return $mw;
}

=pod

=item I<$iowin> = I<$mw>->StdioWindow;

Returns a reference to the main window holding the text. You can use this to
configure the window itself or the widgets it contains. The only advertised
subwidget is 'text', which is the scrolled read-only text widget.

=cut

##==============================================================================
## StdioWindow
##==============================================================================
sub StdioWindow {
    return $io_window;
}

=pod

=item I<$old> = I<$mw>->RedirectStdio(I<$boolean>);

Enables or disables the redirection of standard output and error to the text window.
Set I<$boolean> to true to enable redirection, false to disable it. Returns the
previous value of the enabled flag.

If B<InitStdio> has never been called, this routine will call it if I<$boolean>
is true.

=cut

##==============================================================================
## RedirectStdio
##==============================================================================
sub RedirectStdio {
    my ( $mw, $boolean ) = @_;

    unless ( defined $io_window ) {
        $mw->InitStdio if $boolean;
        return;
    }
    return $io_window->Redirect($boolean);
}

=pod

=back

=head1 AUTHOR

Alan Stewart <F<astewart1>@F<cox>.F<net>>
based on Tk::Stderr by Kevin Michael Vail <F<kevin>@F<vaildc>.F<net>>

=cut

##==============================================================================
## Define the handle that actually implements things.
##==============================================================================
BEGIN {

    package Tk::Stdio::Handle;
    use strict;
    use warnings;

    ##==========================================================================
    ## TIEHANDLE
    ##==========================================================================
    sub TIEHANDLE {
        my ( $class, $window ) = @_;
        bless \$window, $class;
    }

    ##==========================================================================
    ## PRINT
    ##==========================================================================
    sub PRINT {
        my $window = shift;
        my $text   = $$window->Subwidget('text');

        $text->configure( -state => 'normal' );
        $text->insert( 'end', $_ ) foreach (@_);
        $text->configure( -state => 'disabled' );
        $text->see('end');
        $text->SetCursor('end');
        $$window->deiconify;
        $$window->raise;
        $$window->focus;
    }

    ##==========================================================================
    ## PRINTF
    ##==========================================================================
    sub PRINTF {
        my ( $window, $format ) = splice @_, 0, 2;

        $window->PRINT( sprintf $format, @_ );
    }

    ##==========================================================================
    ## READLINE
    ##==========================================================================
    sub READLINE {
        my $window = shift;
        my $text   = $$window->Subwidget('text');

        $text->see('end');
        $$window->deiconify;
        $$window->raise;
        $text->focus;

        $Tk::Stdio::first_char = $text->index('insert');
        my $next_line = int( $Tk::Stdio::first_char + 1 );
        $text->configure( -state => 'normal' );
        $text->update until $text->index('insert') == $next_line;
        $text->configure( -state => 'disabled' );
        return $text->get( $Tk::Stdio::first_char, $text->index('insert') );
    }

    ##==========================================================================
    ## GETC
    ##==========================================================================
    sub GETC {
        my $window = shift;
        my $text   = $$window->Subwidget('text');

        $text->see('end');
        $$window->deiconify;
        $$window->raise;
        $text->focus;

        $Tk::Stdio::first_char = $text->index('insert');
        $text->configure( -state => 'normal' );
        $text->update until $text->index('insert') > $Tk::Stdio::first_char;
        $text->configure( -state => 'disabled' );
        return $text->get($Tk::Stdio::first_char);
    }

}

1;
##==============================================================================
## Stdio.pm
## Revision 1.0  2004/07/26 12:00:00  astewart
##==============================================================================
## Stdio.pm is based on:
##
## $Log: Stderr.pm,v $
## Revision 1.2  2003/04/01 03:58:42  kevin
## Add RedirectStderr method to allow redirection to be switched on and off.
##
## Revision 1.1  2003/03/26 21:48:43  kevin
## Fix dependencies in Makefile.PL
##
## Revision 1.0  2003/03/26 19:11:32  kevin
## Initial revision
##==============================================================================