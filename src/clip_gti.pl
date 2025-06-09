#! /usr/bin/perl

use warnings;
use strict;

my $version = '0.1';

use Astro::FITS::CFITSIO;
use Carp;
use Config;
use Data::Dumper;
use FindBin;
use File::Copy;

use Getopt::Long;
my %default_opts = (
		    );
my %opts = %default_opts;
GetOptions(\%opts,
	   'help!', 'version!', 'debug!',
	   ) or die "Try --help for more information.\n";
if ($opts{debug}) {
  $SIG{__WARN__} = \&Carp::cluck;
  $SIG{__DIE__} = \&Carp::confess;
}
$opts{help} and _help();
$opts{version} and _version();

@ARGV == 3 or
  die "Usage: $0 arch_gti hps_gti clipped_gti\n";

my ($arch_gti, $hps_gti, $clipped_gti) = @ARGV;

my ($fptr, $start, $stop) = read_gti($arch_gti, Astro::FITS::CFITSIO::READONLY());
my $arch_start = $start->[0];
my $s=0;
$fptr->close_file($s);

copy($hps_gti, $clipped_gti);
($fptr, $start, $stop) = read_gti($clipped_gti, Astro::FITS::CFITSIO::READWRITE());

my $rewrite;

my $n_delete = 0;
for my $i (0..$#{$stop}) {
  $stop->[$i] >= $arch_start and last;
  $n_delete++
}

if ($n_delete) {
  $rewrite = 1;
  $fptr->delete_rows(1, $n_delete, $s);
  ($start, $stop) = read_start_stop($fptr, $s);
}

if ($start->[0] < $arch_start) {
  $rewrite = 1;
  $start->[0] = $arch_start;
}

if ($rewrite) {
  write_start_stop($fptr, $start, $stop, $s);
  my $nhdus;
  $fptr->get_num_hdus($nhdus, $s);
  for my $i (1..$nhdus) {
    $fptr->movabs_hdu($i, undef, $s);
    $fptr->update_key_str('creator', $FindBin::Bin . '/' . $FindBin::RealScript, undef, $s);
    $fptr->write_date($s);
    $fptr->write_chksum($s);
  }
}

$fptr->close_file($s);

exit 0;

sub write_start_stop {
  my ($fptr, $start, $stop) = @_;
  my ($start_colnum, $stop_colnum);
  my $nrows = @$start;
  $fptr->get_colnum(0, 'start', $start_colnum, $_[3]);
  $fptr->get_colnum(0, 'stop', $stop_colnum, $_[3]);
  $fptr->write_col_dbl($start_colnum, 1, 1, $nrows, $start, $_[3]);
  $fptr->write_col_dbl($stop_colnum, 1, 1, $nrows, $stop, $_[3]);
}

sub read_gti {
  @_ == 2 or die;
  my ($file, $mode) = @_;
  my $s = 0;
  my $fptr = Astro::FITS::CFITSIO::open_file($file, $mode, $s);

  my ($start, $stop) = read_start_stop($fptr, $s);

  check_status($s) or croak;

  return $fptr, $start, $stop
}

sub read_start_stop {
  my $fptr = shift;
  $fptr->movnam_hdu(Astro::FITS::CFITSIO::BINARY_TBL(), 'gti', 0, $_[0]);

  my $nrows;
  $fptr->get_num_rows($nrows, $_[0]);

  my ($start_colnum, $stop_colnum);
  $fptr->get_colnum(0, 'start', $start_colnum, $_[0]);
  $fptr->get_colnum(0, 'stop', $stop_colnum, $_[0]);

  my ($nulval, $anynul) = -1;

  my ($start, $stop);
  $fptr->read_col_dbl($start_colnum, 1, 1, $nrows, $nulval, $start, $anynul, $_[0]);
  $fptr->read_col_dbl($stop_colnum, 1, 1, $nrows, $nulval, $stop, $anynul, $_[0]);

  check_status($_[0]) or croak;

  return $start, $stop;
}

sub check_status {
  my $s = shift;
  if ($s != 0) {
    my $txt;
    Astro::FITS::CFITSIO::fits_get_errstatus($s,$txt);
    carp "CFITSIO error: $txt";
    return 0;
  }
  return 1;
}
  
sub _help {
  exec("$Config{installbin}/perldoc", '-F', $FindBin::Bin . '/' . $FindBin::RealScript);
}

sub _version {
  print $version,"\n";
  exit 0;
}

=head1 NAME

template - A template for Perl programs.

=head1 SYNOPSIS

cp template newprog

=head1 DESCRIPTION

blah blah blah

=head1 OPTIONS

=over 4

=item --help

Show help and exit.

=item --version

Show version and exit.

=back

=head1 AUTHOR

Pete Ratzlaff E<lt>pratzlaff@cfa.harvard.eduE<gt> May 2012

=head1 SEE ALSO

perl(1).

=cut

