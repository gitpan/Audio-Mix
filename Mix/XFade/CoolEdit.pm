package Audio::Mix::XFade::CoolEdit;

use strict;
use Audio::CoolEdit;
use Audio::Tools::Time;

sub new {
	my $class = shift;
	my $settings = shift;

	my $analyse = shift;
	my $self = $settings;
	$self -> {'analyse'} = $analyse;
	$self -> {'breaks'} = [];
	&_init( $self );
	bless $self, $class;
	return $self;
}

sub _init {
	my $self = shift;
	my @get = qw( offsets order length cues write_details first_sig last_sig read );
	my $analyse = $self -> {'analyse'};
	foreach my $get ( @get ) {
		$self -> {$get} = $analyse -> get_data( $get );
	}
	my @get_details = qw( block_align channels );
	my $details = $self -> {'write_details'};
	$self -> {'times'} = Audio::Tools::Time -> new( map $details -> {$_}, qw( sample_rate bits_sample channels ) );

	foreach my $get ( @get_details ) {
		$self -> {$get} = $details -> {$get};
	}
}

sub mix {
	my $self = shift;

	my $offset = $self -> {'offsets'};
	my $order = $self -> {'order'};
	my $analyse = $self -> {'analyse'};

	my $last_file = $order -> [ $#$order ];
	my $samples = $self -> {'length'} -> {$last_file};
	$samples += $offset -> {$last_file};

	my $times = $self -> {'times'};

	print "length: ", $times -> nice_time( $times -> bytes_to_seconds( $samples ) ), " ($samples bytes)\n";

	my $read = $self -> {'read'};

	my $block_align = $self -> {'block_align'};
	my $out_dir = $self -> {'dirs'} -> {'out'};
	my $out_file = $self -> {'outfile'};
	my $write_details = $self -> {'write_details'};

	my( $write, $file_count );
	my $cool = new Audio::CoolEdit;
	$write = $cool -> write( join( '/', $out_dir, $out_file ), $write_details );
	$self -> {'write'} = $write;
	my $first_sig = $self -> {'first_sig'};

	my %split_pos;

	foreach my $id ( 0 .. $#$order ) {
		my $file = $order -> [$id];
		my $oset = $offset -> {$file};
		my $length = $self -> {'length'} -> {$file};
		my $cues = $self -> {'cues'} -> {$file};

		my $fade_rec = {};
		foreach my $fade_type ( qw( in out ) ) {
			my $fade_str = 'fade_' . $fade_type;
			next unless ( exists $cues -> {$fade_str} );
			$fade_rec -> {$fade_type} = $cues -> {$fade_str};
		}

		my $record =	{
					'file'		=> $file,
					'offset'	=> $oset,
					'length'	=> $length,
					'title'		=> "song ($id)",
					'fade'		=> $fade_rec,
				};

		my $copy = $cues -> {'copy'};
		unless ( exists $cues -> {'fade_in'} ) {
			if ( $copy -> {'start'} > 0 ) {
				$record -> {'start'} = $copy -> {'start'};
			}
		}
		unless ( exists $cues -> {'fade_out'} ) {
			if ( $copy -> {'end'} < $length ) {
				$record -> {'end'} = $copy -> {'end'};
			}
		}

		$write -> add_file( $record );

		if ( $id ) {
			my $spl_pos = $oset + $first_sig -> {$file};
			$write -> add_cue( $oset, map $analyse -> $_( $file ), qw( band song ) );
			push @{ $self -> {'breaks'} }, $spl_pos;
		} else {
			push @{ $self -> {'breaks'} }, 0;
			$write -> add_cue( 0, map $analyse -> $_( $file ), qw( band song ) );
		}
	}
	$write -> finish();
}

sub dao_cue_file {
	my $self = shift;

	my $breaks = $self -> {'breaks'};
	my $file = $self -> {'write'} -> file_name();
	my $out_dir = $self -> {'dirs'} -> {'out'};
	my $out_file = $self -> {'outfile'};

	my $details = $self -> {'write_details'};

	my $to_file = join ( '', $out_dir, '/', $out_file, '.cue' );

	$self -> {'times'} -> dao_cue_file( $breaks, $file, $to_file );
}

1;

