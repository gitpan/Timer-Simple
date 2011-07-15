# vim: set sw=2 sts=2 ts=2 expandtab smarttab:
#
# This file is part of Timer-Simple
#
# This software is copyright (c) 2011 by Randy Stauner.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict;
use warnings;

package Timer::Simple;
BEGIN {
  $Timer::Simple::VERSION = '1.004';
}
BEGIN {
  $Timer::Simple::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Small, simple timer (stopwatch) object

use Carp qw(croak carp); # core
use overload # core
  '""' => \&string,
  '0+' => \&elapsed,
  fallback => 1;


sub new {
  my $class = shift;
  my $self = {
    start => 1,
    string => 'short',
    hires => HIRES(),
    @_ == 1 ? %{$_[0]} : @_,
  };

  if( $self->{format} ){
    carp("$class option 'format' is deprecated.  Use 'hms' (or 'string')");
    $self->{hms} ||= delete $self->{format};
  }
  $self->{hms} ||= default_format_spec($self->{hires});

  bless $self, $class;

  $self->start
    if $self->{start};

  return $self;
}


sub elapsed {
  my ($self) = @_;

  if( !defined($self->{started}) ){
    croak("Timer never started!");
  }

  # if stop() was called, use that time, otherwise "now"
  my $elapsed = defined($self->{stopped})
    ? $self->{stopped}
    : $self->time;

  return $self->{hires}
    ? Time::HiRes::tv_interval($self->{started}, $elapsed)
    : $elapsed - $self->{started};
}


sub hms {
  my ($self, $format) = @_;

  my ($h, $m, $s) = separate_hms($self->elapsed);

  return wantarray
    ? ($h, $m, $s)
    : sprintf(($format || $self->{hms}), $h, $m, $s);
}


sub start {
  my ($self) = @_;

  # don't use an old stopped time if we're restarting
  delete $self->{stopped};

  $self->{started} = $self->time;
}


sub stop {
  my ($self) = @_;
  $self->{stopped} = $self->time
    # don't change the clock if it's already stopped
    if !defined($self->{stopped});
  # natural return value would be elapsed() but don't compute it in void context
  return $self->elapsed
    if defined wantarray;
}


sub string {
  my ($self, $format) = @_;
  $format ||= $self->{string};

  # if it's a method name or a coderef delegate to it
  return scalar $self->$format()
    if $self->can($format)
      || ref($format) eq 'CODE'
      || overload::Method($format, '&{}');

  # cache the time so that all formats show the same (in case it isn't stopped)
  my $seconds = $self->elapsed;

  my $string;
  if( $format eq 'short' ){
    $string = sprintf('%ss (' . $self->{hms} . ')', $seconds, separate_hms($seconds));
  }
  elsif( $format =~ /human|full/ ){
    # human
    $string = sprintf('%d hours %d minutes %s seconds', separate_hms($seconds));
    $string = $seconds . ' seconds (' . $string . ')'
      if $format eq 'full';
  }
  else {
    croak("Unknown format: $format");
  }
  return $string;
}


sub time {
  return $_[0]->{hires}
    ? [ Time::HiRes::gettimeofday() ]
    : time;
}

{
  # aliases
  no warnings 'once';
  *restart = \&start;
}

# package functions


{
  # only perform the check once, but don't perform the check until required
  my $HIRES;
  sub HIRES () {  ## no critic Prototypes
    $HIRES = (do { local $@; eval { require Time::HiRes; 1; } } || '')
      if !defined($HIRES);
    return $HIRES;
  }
}


sub default_format_spec {
  my ($fractional) = @_ ? @_ : HIRES();
  # float: 9 (width) - 6 (precision) - 1 (dot) == 2 digits before decimal point
  return '%02d:%02d:' . ($fractional ? '%09.6f' : '%02d');
}


sub format_hms {
  # if only one argument was provided assume its seconds and split it
  my ($h, $m, $s) = (@_ == 1 ? separate_hms(@_) : @_);

  return sprintf(default_format_spec(int($s) != $s), $h, $m, $s);
}


sub separate_hms {
  my ($s)  = @_;

  # find the number of whole hours, then subtract them
  my $h  = int($s / 3600);
     $s -=     $h * 3600;
  # find the number of whole minutes, then subtract them
  my $m  = int($s / 60);
     $s -=     $m * 60;

  return ($h, $m, $s);
}

1;


__END__
=pod

=for :stopwords Randy Stauner hms cpan testmatrix url annocpan anno bugtracker rt cpants
kwalitee diff irc mailto metadata placeholders

=head1 NAME

Timer::Simple - Small, simple timer (stopwatch) object

=head1 VERSION

version 1.004

=head1 SYNOPSIS

  use Timer::Simple ();
  my $t = Timer::Simple->new();
  do_something;
  print "something took: $t\n";

  # or take more control

  my $timer = Timer::Simple->new(start => 0, string => 'human');
    do_something_before;
  $timer->start;
    do_something_else;
  print "time so far: ", $t->elapsed, " seconds\n";
    do_a_little_more;
  print "time so far: ", $t->elapsed, " seconds\n";
    do_still_more;
  $timer->stop;
    do_something_after;
  printf "whole process lasted %d hours %d minutes %f seconds\n", $t->hms;
    # or simply "whole process lasted $t\n" with 'string' => 'human'

  $timer->restart; # use the same object to time something else

  # you can use package functions to work with mutliple timers

  $timer1 = Timer::Simple->new;
    do_stuff;
  $timer1->stop;
    do_more;
  $timer2 = Timer::Simple->new;
    do_more_stuff;
  $timer2->stop;

  print "first process took $timer1, second process took: $timer2\n";
  print "in total took: " . Timer::Simple::format_hms($timer1 + $timer2);

=head1 DESCRIPTION

This is a simple object to make timing an operation as easy as possible.

It uses L<Time::HiRes> if available (unless you tell it not to).

It stringifies to the elapsed time (see L</string>).

This module aims to be small and efficient
and do what is useful in most cases
while also being sufficiently customizable.

=head1 METHODS

=head2 new

Constructor;  Takes a hash or hashref of arguments:

=over 4

=item *

C<hires> - Boolean; Defaults to true;

Set this to false to not attempt to use L<Time::HiRes>
and just use L<time|perlfunc/time> instead.

=item *

C<hms> - Alternate C<sprintf> string used by L</hms>

=item *

C<start> - Boolean; Defaults to true;

Set this to false to skip the initial setting of the clock.
You must call L</start> explicitly if you disable this.

=item *

C<string> - The default format for L</string>. Defaults to C<'short'>;

=back

=head2 elapsed

Returns the number of seconds elapsed since the clock was started.

This method is used as the object's value when used in numeric context:

  $total_elapsed = $timer1 + $timer2;

=head2 hms

  # list
  my @units = $timer->hms;

  sprintf("%d hours %minutes %f seconds", $timer->hms);

  # scalar
  print "took: " . $timer->hms . "\n"; # same as print "took :$timer\n";

  # alternate format
  $string = $timer->hms('%04d h %04d m %020.10f s');

Separates the elapsed time (seconds) into B<h>ours, B<m>inutes, and B<s>econds.

In list context returns a three-element list (hours, minutes, seconds).

In scalar context returns a string resulting from
C<sprintf>
(essentially C<sprintf($format, $h, $m, $s)>).
The default format is
C<00:00:00.000000> (C<%02d:%02d:%9.6f>) with L<Time::HiRes> or
C<00:00:00> (C<%02d:%02d:%02d>) without.
An alternate C<format> can be specified in L</new>
or can be passed as an argument to the method.

=head2 start
X<restart>

Initializes the timer to the current system time.

Aliased as C<restart>.

=head2 stop

Stop the timer.
This records the current system time in case you'd like to do more
processing (that you don't want timed) before reporting the elapsed time.

=head2 string

  print $timer->string($format);

  print "took: $timer";  # stringification equivalent to $timer->string()

Returns a string representation of the elapsed time.

The format can be passed as an argument.  If no format is provided
the value of C<string> (passed to L</new>) will be used.

The format can be the name of another method (which will be called),
a subroutine (coderef) which will be called like an object method,
or one of the following strings:

=over 4

=item *

C<short> - Total elapsed seconds followed by C<hms>: C<'123s (00:02:03)'>

=item *

C<human> - Separate units spelled out: C<'6 hours 4 minutes 12 seconds'>

=item *

C<full> - Total elapsed seconds plus C<human>: C<'2 seconds (0 hours 0 minutes 2 seconds)'>

=back

This is the method called when the object is stringified (using L<overload>).

=head2 time

Returns the current system time
using L<Time::HiRes/gettimeofday> or L<time|perlfunc/time>.

=head1 FUNCTIONS

=head2 HIRES

Indicates whether L<Time::HiRes> is available.

=head2 default_format_spec

  $spec            = default_format_spec();  # consults HIRES()
  $spec_whole      = default_format_spec(0); # false forces integer
  $spec_fractional = default_format_spec(1); # true  forces fraction

Returns an appropriate C<sprintf> format spec according to the provided boolean.
If true,  the spec forces fractional seconds (like C<'00:00:00.000000'>).
If false, the spec forces seconds to an integer (like C<'00:00:00'>).
If not specified the value of L</HIRES> will be used.

=head2 format_hms

  my $string = format_hms($hours, $minutes, $seconds);
  my $string = format_hms($seconds);

Format the provided hours, minutes, and seconds
into a string by guessing the best format.

If only seconds are provided
the value will be passed through L</separate_hms> first.

=head2 separate_hms

  my ($hours, $minutes, $seconds) = separate_hms($seconds);

Separate seconds into hours, minutes, and seconds.
Returns a list.

=head1 FUNCTIONS

The following functions should not be necessary in most circumstances
but are provided for convenience to facilitate additional functionality.

They are not available for export (to avoid L<Exporter> overhead).
See L<Sub::Import> if you really want to import these methods.

=for test_synopsis my ( $timer1, $timer2 );
no strict 'subs';

=head1 SEE ALSO

These are some other timers I found on CPAN
and how they differ from this module:

=over 4

=item *

L<Time::Elapse> - eccentric API to a tied scalar

=item *

L<Time::Progress> - Doesn't support L<Time::HiRes>

=item *

L<Time::StopWatch> - tied scalar

=item *

L<Dancer::Timer> - inside Dancer framework

=back

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc Timer::Simple

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/Timer-Simple>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Timer-Simple>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/Timer-Simple>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/T/Timer-Simple>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Timer-Simple>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Timer::Simple>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-timer-simple at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Timer-Simple>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code


L<http://github.com/rwstauner/Timer-Simple>

  git clone http://github.com/rwstauner/Timer-Simple

=head1 AUTHOR

Randy Stauner <rwstauner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Randy Stauner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

