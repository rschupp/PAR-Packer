#line 1
package Test::Builder::IO::Scalar;


#line 28

# This is copied code, I don't care.
##no critic

use Carp;
use strict;
use vars qw($VERSION @ISA);
use IO::Handle;

use 5.005;

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = "2.110";

### Inheritance:
@ISA = qw(IO::Handle);

#==============================

#line 52

#------------------------------

#line 62

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = bless \do { local *FH }, $class;
    tie *$self, $class, $self;
    $self->open(@_);   ### open on anonymous by default
    $self;
}
sub DESTROY {
    shift->close;
}

#------------------------------

#line 87

sub open {
    my ($self, $sref) = @_;

    ### Sanity:
    defined($sref) or do {my $s = ''; $sref = \$s};
    (ref($sref) eq "SCALAR") or croak "open() needs a ref to a scalar";

    ### Setup:
    *$self->{Pos} = 0;          ### seek position
    *$self->{SR}  = $sref;      ### scalar reference
    $self;
}

#------------------------------

#line 109

sub opened {
    *{shift()}->{SR};
}

#------------------------------

#line 123

sub close {
    my $self = shift;
    %{*$self} = ();
    1;
}

#line 133



#==============================

#line 143


#------------------------------

#line 153

sub flush { "0 but true" }

#------------------------------

#line 164

sub getc {
    my $self = shift;

    ### Return undef right away if at EOF; else, move pos forward:
    return undef if $self->eof;
    substr(${*$self->{SR}}, *$self->{Pos}++, 1);
}

#------------------------------

#line 183

sub getline {
    my $self = shift;

    ### Return undef right away if at EOF:
    return undef if $self->eof;

    ### Get next line:
    my $sr = *$self->{SR};
    my $i  = *$self->{Pos};	        ### Start matching at this point.

    ### Minimal impact implementation!
    ### We do the fast fast thing (no regexps) if using the
    ### classic input record separator.

    ### Case 1: $/ is undef: slurp all...
    if    (!defined($/)) {
	*$self->{Pos} = length $$sr;
        return substr($$sr, $i);
    }

    ### Case 2: $/ is "\n": zoom zoom zoom...
    elsif ($/ eq "\012") {

        ### Seek ahead for "\n"... yes, this really is faster than regexps.
        my $len = length($$sr);
        for (; $i < $len; ++$i) {
           last if ord (substr ($$sr, $i, 1)) == 10;
        }

        ### Extract the line:
        my $line;
        if ($i < $len) {                ### We found a "\n":
            $line = substr ($$sr, *$self->{Pos}, $i - *$self->{Pos} + 1);
            *$self->{Pos} = $i+1;            ### Remember where we finished up.
        }
        else {                          ### No "\n"; slurp the remainder:
            $line = substr ($$sr, *$self->{Pos}, $i - *$self->{Pos});
            *$self->{Pos} = $len;
        }
        return $line;
    }

    ### Case 3: $/ is ref to int. Do fixed-size records.
    ###        (Thanks to Dominique Quatravaux.)
    elsif (ref($/)) {
        my $len = length($$sr);
		my $i = ${$/} + 0;
		my $line = substr ($$sr, *$self->{Pos}, $i);
		*$self->{Pos} += $i;
        *$self->{Pos} = $len if (*$self->{Pos} > $len);
		return $line;
    }

    ### Case 4: $/ is either "" (paragraphs) or something weird...
    ###         This is Graham's general-purpose stuff, which might be
    ###         a tad slower than Case 2 for typical data, because
    ###         of the regexps.
    else {
        pos($$sr) = $i;

	### If in paragraph mode, skip leading lines (and update i!):
        length($/) or
	    (($$sr =~ m/\G\n*/g) and ($i = pos($$sr)));

        ### If we see the separator in the buffer ahead...
        if (length($/)
	    ?  $$sr =~ m,\Q$/\E,g          ###   (ordinary sep) TBD: precomp!
            :  $$sr =~ m,\n\n,g            ###   (a paragraph)
            ) {
            *$self->{Pos} = pos $$sr;
            return substr($$sr, $i, *$self->{Pos}-$i);
        }
        ### Else if no separator remains, just slurp the rest:
        else {
            *$self->{Pos} = length $$sr;
            return substr($$sr, $i);
        }
    }
}

#------------------------------

#line 273

sub getlines {
    my $self = shift;
    wantarray or croak("can't call getlines in scalar context!");
    my ($line, @lines);
    push @lines, $line while (defined($line = $self->getline));
    @lines;
}

#------------------------------

#line 294

sub print {
    my $self = shift;
    *$self->{Pos} = length(${*$self->{SR}} .= join('', @_) . (defined($\) ? $\ : ""));
    1;
}
sub _unsafe_print {
    my $self = shift;
    my $append = join('', @_) . $\;
    ${*$self->{SR}} .= $append;
    *$self->{Pos}   += length($append);
    1;
}
sub _old_print {
    my $self = shift;
    ${*$self->{SR}} .= join('', @_) . $\;
    *$self->{Pos} = length(${*$self->{SR}});
    1;
}


#------------------------------

#line 324

sub read {
    my $self = $_[0];
    my $n    = $_[2];
    my $off  = $_[3] || 0;

    my $read = substr(${*$self->{SR}}, *$self->{Pos}, $n);
    $n = length($read);
    *$self->{Pos} += $n;
    ($off ? substr($_[1], $off) : $_[1]) = $read;
    return $n;
}

#------------------------------

#line 345

sub write {
    my $self = $_[0];
    my $n    = $_[2];
    my $off  = $_[3] || 0;

    my $data = substr($_[1], $off, $n);
    $n = length($data);
    $self->print($data);
    return $n;
}

#------------------------------

#line 366

sub sysread {
  my $self = shift;
  $self->read(@_);
}

#------------------------------

#line 380

sub syswrite {
  my $self = shift;
  $self->write(@_);
}

#line 389


#==============================

#line 398


#------------------------------

#line 408

sub autoflush {}

#------------------------------

#line 419

sub binmode {}

#------------------------------

#line 429

sub clearerr { 1 }

#------------------------------

#line 439

sub eof {
    my $self = shift;
    (*$self->{Pos} >= length(${*$self->{SR}}));
}

#------------------------------

#line 452

sub seek {
    my ($self, $pos, $whence) = @_;
    my $eofpos = length(${*$self->{SR}});

    ### Seek:
    if    ($whence == 0) { *$self->{Pos} = $pos }             ### SEEK_SET
    elsif ($whence == 1) { *$self->{Pos} += $pos }            ### SEEK_CUR
    elsif ($whence == 2) { *$self->{Pos} = $eofpos + $pos}    ### SEEK_END
    else                 { croak "bad seek whence ($whence)" }

    ### Fixup:
    if (*$self->{Pos} < 0)       { *$self->{Pos} = 0 }
    if (*$self->{Pos} > $eofpos) { *$self->{Pos} = $eofpos }
    return 1;
}

#------------------------------

#line 476

sub sysseek {
    my $self = shift;
    $self->seek (@_);
}

#------------------------------

#line 490

sub tell { *{shift()}->{Pos} }

#------------------------------

#line 503

sub use_RS {
    my ($self, $yesno) = @_;
    carp "use_RS is deprecated and ignored; \$/ is always consulted\n";
 }

#------------------------------

#line 517

sub setpos { shift->seek($_[0],0) }

#------------------------------

#line 528

*getpos = \&tell;


#------------------------------

#line 540

sub sref { *{shift()}->{SR} }


#------------------------------
# Tied handle methods...
#------------------------------

# Conventional tiehandle interface:
sub TIEHANDLE {
    ((defined($_[1]) && UNIVERSAL::isa($_[1], __PACKAGE__))
     ? $_[1]
     : shift->new(@_));
}
sub GETC      { shift->getc(@_) }
sub PRINT     { shift->print(@_) }
sub PRINTF    { shift->print(sprintf(shift, @_)) }
sub READ      { shift->read(@_) }
sub READLINE  { wantarray ? shift->getlines(@_) : shift->getline(@_) }
sub WRITE     { shift->write(@_); }
sub CLOSE     { shift->close(@_); }
sub SEEK      { shift->seek(@_); }
sub TELL      { shift->tell(@_); }
sub EOF       { shift->eof(@_); }

#------------------------------------------------------------

1;

__END__



#line 576


#line 657

