package Audio::Mix::Analyse;

use strict;
use Audio::Tools::Time;
use Audio::Tools::Fades;
use Audio::Mix::Hints;

sub new {
	my $class = shift;
	my $hints = shift;
	my $out_dir = shift;
	my $read = shift;
	my $default_fades = shift;
	my $details = $read -> details();
	my $times = Audio::Tools::Time -> new( map $details -> {$_}, qw( sample_rate bits_sample channels ) );
	my $length = $read -> length();
	my $self =	{
				'buffer_size'		=> 512,
				'details'		=> $details,
				'times'			=> $times,
				'read'			=> $read,
				'length'		=> $length,
				'start'			=> 0,
				'end'			=> $length,
				'hints'			=> $hints,
				'default_fades'		=> $default_fades,
			};
	bless $self, $class;
	$self -> _init();
	return $self;
}

sub get_start {
	my $self = shift;
	return $self -> {'start'};
}

sub get_end {
	my $self = shift;
	return $self -> {'end'};
}

sub get_info {
	my $self = shift;
	return $self -> {'info'};
}

sub get_cues {
	my $self = shift;
	return $self -> {'actions'};
}

sub get_signif {
	my $self = shift;
	my $data = $self -> {'readcues'};
	my $output =	{
			'first'	=> $data -> {'first_sig'},
			'last'	=> $data -> {'last_sig'},
			};
	return $output;
	return $self -> {'signif'};
}

##########

sub _init {
	my $self = shift;

	my $file = $self -> {'read'} -> file_name();

#	print "file: $file\n";

	my $hints =$self -> {'hints'};
	my $hint = Audio::Mix::Hints ->	new(
						$hints -> {'dir'},
						map( $self -> {$_}, qw( read times ) )
					);
	$self -> {'cues'} = $self -> _cues();
	$self -> {'readcues'} = $self -> _analyse_cues();
	$self -> {'info'} = $self -> _read_info();
	if ( exists( $hints -> {'mode'} ) && $hints -> {'mode'} eq 'read' ) {
		$hint -> read( map $self -> {$_}, qw( readcues info ) );
	}
	$self -> {'start'} = $self -> {'readcues'} -> {'start'};
	$self -> {'end'} = $self -> {'readcues'} -> {'end'};

	$self -> {'actions'} = $self -> _read_actions();
#	$self -> {'signif'} = $self -> _read_signif();

#print Data::Dumper->Dump([ $self ]);
#exit;

	if ( exists( $hints -> {'mode'} ) && $hints -> {'mode'} eq 'write' ) {
		$hint -> save( map $self -> {$_}, qw( info readcues ) );
	}
#	print Data::Dumper->Dump([ $hints ]);
#	exit;
}

sub _cues {
	my $self = shift;
	my $read = $self -> {'read'};
	my $cues = $read -> get_cues();
	my $block_align = $self -> {'details'} -> {'block_align'};
	my $output = {};
	foreach my $id ( keys %$cues ) {
		my $data = $cues -> {$id};
		next unless exists( $data -> {'label'} );
		my $label = $data -> {'label'};
		my @output = ( $data -> {'position'} * $block_align );
		push( @output, $data -> {'note'} ) if exists( $data -> {'note'} );
		push @{ $output -> {$label} }, [ @output ];
	}
	return $output;
}

sub _analyse_cues {
	my $self = shift;
	my $cues = $self -> {'cues'};
	my $output = {};
	my $samp_len = $self -> {'length'};

	my $start = 0;
	my $end = $samp_len;

	$start = $cues -> {'start'} -> [0] -> [0] if exists( $cues -> {'start'} );
	$end = $cues -> {'end'} -> [0] -> [0] if exists( $cues -> {'end'} );

	$samp_len = $end - $start;

	$output -> {'start'} = $start;
	$output -> {'end'} = $end;

	if ( exists $cues -> {'sig'} ) {
		my $sigs = $cues -> {'sig'};
		my $sig_cnt = $#$sigs;
		for my $id ( 0 .. $sig_cnt ) {
			next unless $sigs -> [$id] -> [1] eq 'first';
			$output -> {'first_sig'} = $sigs -> [$id] -> [0];
			last;
		}
		for my $id ( reverse 0 .. $sig_cnt ) {
			next unless $sigs -> [$id] -> [1] eq 'last';
			$output -> {'last_sig'} = $sigs -> [$id] -> [0];
			last;
		}
	}

	my $auto_fade = $self -> {'default_fades'} -> {'auto'};
	my $times = $self -> {'times'};

	my $default_type = $self -> {'default_fades'} -> {'type'};
	my $default;
	if ( $auto_fade ) {
		$default = $times -> seconds_to_bytes( $self -> {'default_fades'} -> {'time'} );
	 	$default = $times -> nice_bytes( $samp_len / 4 ) if $default > $samp_len;
		my $default_sig = $times -> nice_bytes( $default / 2 );
		$output -> {'first_sig'} = $start + $default_sig unless exists( $output -> {'first_sig'} );
		$output -> {'last_sig'} = $end - $default_sig unless exists( $output -> {'last_sig'} );
	} else {
		$output -> {'first_sig'} = $start unless exists( $output -> {'first_sig'} );
		$output -> {'last_sig'} = $end unless exists( $output -> {'last_sig'} );
	}

	if ( exists $cues -> {'fade_in'} ) {
		my $fades = $cues -> {'fade_in'} -> [0];
		$output -> {'fade_in'} = $fades -> [0];
		$output -> {'fade_in_type'} = $fades -> [1] ? $fades -> [1] : $default_type;
	} else {
		if ( $auto_fade ) {
			$output -> {'fade_in'} = $start + $default;
			$output -> {'fade_in_type'} = $default_type;
		}
	}

	if ( exists $cues -> {'fade_out'} ) {
		my $fades = $cues -> {'fade_out'} -> [-1];
		$output -> {'fade_out'} = $fades -> [0];
		$output -> {'fade_out_type'} = $fades -> [1] ? $fades -> [1] : $default_type;
	} else {
		if ( $auto_fade ) {
			$output -> {'fade_out'} = $end - $default;
			$output -> {'fade_out_type'} = $default_type;
		}
	}

	return $output;
}

sub _read_actions {
	my $self = shift;
	my $data = $self -> {'readcues'};

	my $filters = new Audio::Tools::Fades;

	my $start = $data -> {'start'};
	my $end = $data -> {'end'};

	my $actions = {};

	my( $fade_in, $fade_out );

	if ( exists $data -> {'fade_in'} ) {
		$fade_in = $data -> {'fade_in'};
		my $in_type = $data -> {'fade_in_type'};
		$actions -> {'fade_in'}	=	{
						'start'	=> $start,
						'end'	=> $fade_in,
						'sub'	=> 'filter',
						'fade'	=> $filters -> fade( $fade_in - $start, 0, $in_type ),
						'type'	=> $in_type,
						};
	} else {
		$fade_in = $start;
	}

	if ( exists $data -> {'fade_out'} ) {
		$fade_out = $data -> {'fade_out'};
		my $out_type = $data -> {'fade_out_type'};
		$actions -> {'fade_out'} =	{
						'start'	=> $fade_out,
						'end'	=> $end,
						'sub'	=> 'filter',
						'fade'	=> $filters -> fade( $end - $fade_out, 1, $out_type ),
						'type'	=> $out_type,
						};
	} else {
		$fade_out = $end;
	}

	$actions -> {'copy'} =	{
				'start' => $fade_in,
				'end'	=> $fade_out,
				'sub'	=> 'copy',
				'fade'	=> $self -> {'buffer_size'},
				};

	return $actions;
}

sub _read_info {
	my $self = shift;
	my $info = $self -> {'read'} -> get_info();
	my %direct =	(
			'name'		=> 'song',
			'artist'	=> 'band',
			);

	my %output;
	if ( defined $info ) {
		if ( exists $info -> {'keywords'} ) {
			my $keywords = $info -> {'keywords'};
			if ( $keywords =~ / bpm: (\d+ \.? \d*) /x ) {
				$output{'bpm'} = $1;
			}
			if ( $keywords =~ / key: ([a-g][^\s]*) /x ) {
				$output{'key'} = $1;
			}
		}
		foreach my $type ( keys %direct ) {
			next unless ( exists $info -> {$type} );
			$output{ $direct{$type} } = $info -> {$type};
		}
	}
	return \%output;
}

sub _read_signif {
	my $self = shift;
	my $cues = $self -> {'cues'};
	my $length = $self -> {'length'};
	my $half = int( $length / 2 );
	my %output;
	if ( exists $cues -> {'sig'} ) {
		foreach my $sig ( @{ $cues -> {'sig'} } ) {
			my( $pos, $name ) = @$sig;
			my @spare;
			if ( defined( $name ) && ( $name eq 'first' || $name eq 'last' ) ) {
				$output{$name} = $pos;
			} else {
				push @spare, $pos;
			}
			if ( @spare ) {
				@spare = sort @spare;
				unless ( exists $output{'first'} ) {
					if ( $spare[0] < $half ) {
						$output{'first'} = shift @spare;
					}
				}
				unless ( exists $output{'last'} && @spare ) {
					my $test = pop @spare;
					if ( $test > $half ) {
						$output{'last'} = $test;
					}
				}
			}
		}
	}
	my $times = $self -> {'times'};

	unless ( exists $output{'first'} ) {
		my $start = 0;
		$start = $cues -> {'start'} -> [0] -> [0] if exists( $cues -> {'start'} );
		if ( exists $cues -> {'fade_in'} ) {
			my $fade = $cues -> {'fade_in'} -> [0] -> [0];
			$fade = $times -> nice_bytes( ( $start + $fade ) / 2 );
			$output{'first'} = $fade;
		} else {
			$output{'first'} = $start;
		}
	}

	unless ( exists $output{'last'} ) {
		my $end = $length;
		$end = $cues -> {'end'} -> [0] -> [0] if exists( $cues -> {'end'} );
		if ( exists $cues -> {'fade_out'} ) {
			my $fade = $cues -> {'fade_out'} -> [0] -> [0];
			my $diff = $times -> nice_bytes( ( $end - $fade ) / 2 );
			$output{'last'} = $fade + $diff;
		} else {
			$output{'last'} = $end;
		}
	}
#	print Data::Dumper->Dump([ \%output, $cues ], [ qw( output cues ) ] );

	return \%output;
}

1;
