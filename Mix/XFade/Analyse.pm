package Audio::Mix::XFade::Analyse;

use strict;
use Audio::Wav;
use Audio::Mix::Analyse;

my @check = qw( bits_sample channels sample_rate );

sub new {
	my $class = shift;
	my $settings = shift;
	my $self = {};
	foreach my $key ( keys %$settings ) {
		$self -> {$key} = $settings -> {$key};
	}
	bless $self, $class;
	$self -> _init();
	$self -> {'extract'} = $self -> _extract();
	$self -> {'order'} = $self -> _file_order();
	$self -> _check_files();
	$self -> {'offsets'} = $self -> _offsets();
	return $self;
}


sub get_data {
	my $self = shift;
	my $type = shift;
	return $self -> {$type};
}

sub band {
	my $self = shift;
	my $file = shift;
	return $file unless exists( $self -> {'info'} -> {$file} );
	my $info = $self -> {'info'} -> {$file};
	my $output = exists( $info -> {'band'} ) ? $info -> {'band'} : $file;
	return $output;
}

sub song {
	my $self = shift;
	my $file = shift;
	return '' unless exists( $self -> {'info'} -> {$file} );
	my $info = $self -> {'info'} -> {$file};
	my $output = exists( $info -> {'song'} ) ? $info -> {'song'} : '';
	return $output;
}


sub _init {
	my $self = shift;
	my $files = $self -> {'files'};
	my $default_fades = $self -> {'fades'};

	my $out_dir = $self -> {'dirs'} -> {'out'};
	my $wav = new Audio::Wav;
	foreach my $file ( @$files ) {
		my $read = $wav -> read( $file );
		my $details = $read -> details();
		my $analyse = Audio::Mix::Analyse -> new( $self -> {'hints'}, $out_dir, $read, $default_fades );
		$self -> {'read'} -> {$file} = $read;
		$self -> {'length'} -> {$file} = $read -> length();
		$self -> {'details'} -> {$file} = $details;
		$self -> {'analyse'} -> {$file} = $analyse;
		$self -> {'cues'} -> {$file} = $analyse -> get_cues();
		$self -> {'sig'} -> {$file} = $analyse -> get_signif();
		$self -> {'info'} -> {$file} = $analyse -> get_info();
		$self -> {'start'} -> {$file} = $analyse -> get_start();
		$self -> {'end'} -> {$file} = $analyse -> get_end();
	}
	my $first = $files -> [0];

	warn "i'm choosing the details here";

	my $details = $self -> {'details'} -> {$first};
	foreach my $type ( @check ) {
		$self -> {$type} = $details -> {$type};
	}
	$self -> {'block_align'} = $details -> {'block_align'};
	$self -> {'max_volume'} = ( 2 ** $details -> {'bits_sample'} ) / 2;
	$self -> {'write_details'} = $details;
}

sub _offsets {
	my $self = shift;
	my $order = $self -> {'order'};
	my $sig = $self -> {'sig'};
	my $pos = 0;
	my( %offset, $last_pos );
	foreach my $id ( 0 .. $#$order ) {
		my $file = $order -> [$id];
		my $first = $sig -> {$file} -> {'first'};
		$self -> {'first_sig'} -> {$file} = $first;
		my $last = $sig -> {$file} -> {'last'};
		$self -> {'last_sig'} -> {$file} = $last;
		if ( $id ) {
			$offset{$file} = $last_pos - $first;
			$last_pos = $offset{$file} + $last;
		} else {
			$offset{$file} = $pos;
			$last_pos = $last;
		}

	}

	my @order = sort { $offset{$a} <=> $offset{$b} } keys %offset;

	$self -> {'order'} = \@order;

	if ( $offset{ $order[0] } < 0 ) {
		my $diff = $offset{ $order[0] } * -1;
		foreach my $file ( @order ) {
			$offset{$file} += $diff;
		}
	}

	return \%offset;
}

sub _file_order {
	my $self = shift;
	my $files = $self -> {'files'};
	my $extract = $self -> {'extract'};

	my %bpm_val = map { $_ => $extract -> {$_} -> {'bpm'} } @$files;

	my %order = map { $files -> [$_], $_ + 1 } ( 0 .. $#$files );
	my @bpm_order = sort { $bpm_val{$a} <=> $bpm_val{$b} } @$files;
	my @no_bpm;
	while ( @bpm_order && $bpm_val{ $bpm_order[0] } == 0 ) {
		push @no_bpm, shift( @bpm_order );
	}
#	@bpm_order = reverse @bpm_order;
	if ( @no_bpm ) {
		@no_bpm = sort { $order{$a} <=> $order{$b} } @no_bpm;
		push @bpm_order, @no_bpm;
	}
#	foreach my $file ( @bpm_order ) {
#		print "bpm: $file = $bpm_val{$file}\n";
#	}
	return \@bpm_order;
}

sub _extract {
	my $self = shift;
	my $files = $self -> {'files'};
#	die Data::Dumper->Dump([ $self ]);
	my %values;
	foreach my $file ( @$files ) {
		my %data;
		foreach my $type ( qw( sig info length ) ) {
			next unless exists( $self -> {$type} -> {$file} );
			$data{$type} = $self -> {$type} -> {$file};
		}
		$values{$file} =	{
						'length'	=> $data{'length'},
						'first'		=> $data{'sig'} -> {'first'},
						'last'		=> $data{'sig'} -> {'last'},
					};
		if ( exists $data{'info'} -> {'bpm'} ) {
			$values{$file} -> {'bpm'} = $data{'info'} -> {'bpm'};
		} else {
			$values{$file} -> {'bpm'} = 0;
		}
	}
	return \%values;
}

sub _check_files {
	my $self = shift;
	my $order = $self -> {'order'};
	my $info = $self -> {'info'};
	my $cnt;
	foreach my $file ( @$order ) {
		my $bpm = 0;
		$bpm = $info -> {$file} -> {'bpm'};
		$bpm = 0 unless defined( $bpm );
		$cnt ++;
		print "$cnt) file: $file";
		print " bpm($bpm)" if $bpm;
		print "\n";
		my $details = $self -> {'details'} -> {$file};
		foreach my $type ( @check ) {
#			print "\t$type = ", $details -> {$type}, "\n";
			next unless $type eq $self -> {$type};
			die "blugh - $type eq ", $self -> {$type};
		}
	}
}

1;

