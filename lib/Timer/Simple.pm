# vim: set sw=2 sts=2 ts=2 expandtab smarttab:
#
# This file is part of Timer-Simple
#
# This software is copyright (c) 2011 by Randy Stauner.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package Timer::Simple;
BEGIN {
  $Timer::Simple::VERSION = '1.002';
}
BEGIN {
  $Timer::Simple::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Small, simple timer (stopwatch) object

use strict;
use warnings;
use overload # core
  '""' => \&string,
  '0+' => \&elapsed,
  fallback => 1;


sub new {
  my $class = shift;
  my $self = {
    start => 1,
    hires => HIRES(),
    @_ == 1 ? %{$_[0]} : @_,
  };

  $self->{format} ||= default_format_spec($self->{hires});

  bless $self, $class;

  $self->start
    if $self->{start};

  return $self;
}


sub elapsed {
  my ($self) = @_;

  if( !defined($self->{started}) ){
    # lazy load Carp since this is the only place we use it
    require Carp; # core
    Carp::croak("Timer never started!");
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
    : sprintf(($format || $self->{format}), $h, $m, $s);
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
  # this could be configurable: new(string => 'elapsed') # default 'hms'
  scalar $_[0]->hms;
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
  sub HIRES () {
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

version 1.002

=head1 SYNOPSIS

  use Timer::Simple ();
  my $t = Timer::Simple->new();
  do_something;
  print "something took: $t\n";

  # or take more control

  my $timer = Timer::Simple->new(start => 0);
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

It stringifies to the elapsed time in an hours/minutes/seconds format
(default is C<00:00:00.000000> with L<Time::HiRes> or C<00:00:00> without).

This module aims to be small and efficient
and do what is useful in most cases,
while still offering some configurability to handle edge cases.

=head1 METHODS

=head2 new

Constructor;  Takes a hash or hashref of arguments:

=over 4

=item *

C<start> - Boolean; Defaults to true;

Set this to false to skip the initial setting of the clock.
You must call L</start> explicitly if you disable this.

=item *

C<hires> - Boolean; Defaults to true;

Set this to false to not attempt to use L<Time::HiRes>
and just use L<time|perlfunc/time> instead.

=item *

C<format> - Alternate C<sprintf> string; See L</hms>.

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
  $string = $timer->hms('%04dh %04dm %020.10f');

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

Returns the scalar (C<sprintf>) version of L</hms>.
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
If true,  the spec forces fractional seconds (floating point (C<%f>)).
If false, the spec forces seconds to an integer (whole number (C<%d>)).
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

L<http://search.cpan.org/dist/Timer-Simple>

=item *

RT: CPAN's Bug Tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Timer-Simple>

=item *

AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Timer-Simple>

=item *

CPAN Ratings

L<http://cpanratings.perl.org/d/Timer-Simple>

=item *

CPAN Forum

L<http://cpanforum.com/dist/Timer-Simple>

=item *

CPANTS Kwalitee

L<http://cpants.perl.org/dist/overview/Timer-Simple>

=item *

CPAN Testers Results

L<http://cpantesters.org/distro/T/Timer-Simple.html>

=item *

CPAN Testers Matrix

L<http://matrix.cpantesters.org/?dist=Timer-Simple>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-timer-simple at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Timer-Simple>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code


L<http://github.com/magnificent-tears/Timer-Simple/tree>

  git clone git://github.com/magnificent-tears/Timer-Simple.git

=head1 AUTHOR

Randy Stauner <rwstauner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Randy Stauner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

