use strict;

use Audio::Wav;
use Audio::Tools::Time;

my $wav = new Audio::Wav;

my $sample_rate = 11025;
my $bits_sample = 8;
my $channels = 2;
my $length = 2;
my $lo_freq = 100;
my $hi_freq = 400;

#my $sample_rate = 44100;
#my $bits_sample = 16;
#my $channels = 2;
#my $length = 3;
#my $lo_freq = 20;
#my $hi_freq = 300;

my $time = new Audio::Tools::Time $sample_rate, $bits_sample, $channels;

my $details =	{
		'bits_sample'	=> $bits_sample,
		'sample_rate'	=> $sample_rate,
		'channels'	=> $channels,
		};

sub build {
	my $dir = shift;
	my $down = 1;
	print "Generating test wav files.\n";
	for my $cnt ( 1, 2 ) {
		&make_wav( "$dir/$cnt.wav", $down );
		$down = 0;
	}
}

sub make_wav {
	my $file = shift;
	my $direct = shift;
	my $write = $wav -> write( $file, $details );
	&add_slide( $write, $lo_freq, $hi_freq, $direct, $length );
	&mark_file( $write, $direct, $length );
	$write -> finish();
}

sub mark_file {
	my $write = shift;
	my $dir = shift;
	my $length = shift;
	my $inoutfade = $length / 5;
	my $inoutsig = $inoutfade / 2;
	my $middlefade = $length / 3;
	my $middlesig = $middlefade / 2;
	my @marks;
	if ( $dir ) {
		push @marks, [ $inoutfade, 'fade_in', 'trig' ];
		push @marks, [ $length - $middlefade, 'fade_out', 'linear' ];
		push @marks, [ $length - $middlesig, 'sig', 'last' ];
	} else {
		push @marks, [ $middlefade, 'fade_in', 'linear' ];
		push @marks, [ $middlesig, 'sig', 'first' ];
		push @marks, [ $length - $inoutfade, 'fade_out', 'trig' ];
	}
	foreach my $mark ( @marks ) {
		my $pos = $time -> seconds_to_bytes( shift @$mark );
		$write -> add_cue( $pos, @$mark );
	}
}

sub add_slide {
	my $write = shift;
	my $from_hz = shift;
	my $to_hz = shift;
	my $dir = shift;
	my $length = shift;
	my $diff_hz = $to_hz - $from_hz;
	my $pi = ( 22 / 7 ) * 2;
	$length *= $sample_rate;
	my $max_no =  ( 2 ** $bits_sample ) / 2;
	my $pos = 0;

	while ( $pos < $length ) {
		$pos ++;
		my $dir_pos = $dir ? $length - $pos : $pos;
		my $prog = $dir_pos / $length;
		my $hz = $from_hz + ( $diff_hz * $prog );
		my $cycle = $sample_rate / $hz;
		my $mult = $dir_pos / $cycle;
		my $samp = sin( $pi * $mult ) * $max_no;
		if ( $dir ) {
			$write -> write( 0, $samp );
		} else {
			$write -> write( $samp, 0 );
		}
	}
}

1;
