package Audio::Mix::XFade::Wav;

use strict;
use Audio::Mix::Display;
use Audio::Tools::Time;
use Audio::Wav;

sub new {
	my $class = shift;
	my $settings = shift;
	my $analyse = shift;
	my $self = $settings;
	$self -> {'view'} = 100;
	$self -> {'analyse'} = $analyse;
	$self -> {'breaks'} = [];
	bless $self, $class;
	$self -> _init();
	return $self;
}

sub _init {
	my $self = shift;
	my @get = qw( offsets order length cues write_details first_sig read max_volume start end );
	my $analyse = $self -> {'analyse'};

	foreach my $get ( @get ) {
		$self -> {$get} = $analyse -> get_data( $get );
	}
	my @get_details = qw( block_align channels );
	my $details = $self -> {'write_details'};

	foreach my $get ( @get_details ) {
		$self -> {$get} = $details -> {$get};
	}

	my $times = Audio::Tools::Time -> new( map $details -> {$_}, qw( sample_rate bits_sample channels ) );
	$self -> {'times'} = $times;
	if ( exists( $self -> {'view'} ) && $self -> {'view'} ) {
		my $view = $self -> {'view'} * $self -> {'block_align'};
		my $display = new Audio::Mix::Display $times, $self -> {'channels'};
		if ( defined $display ) {
			$self -> {'display'} = $display;
			$self -> {'view'} = $view;
		} else {
			$self -> {'view'} = '';
		}
	} else {
		$self -> {'view'} = '';
	}
	$self -> {'display'} = '' unless $self -> {'view'};
}

sub mix {
	my $self = shift;
	my $offset = $self -> {'offsets'};
	my $ranges = $self -> _find_ranges();

	my $order = $self -> {'order'};
	my $last_file = $order -> [ $#$order ];
	my $first_file = $order -> [ 0 ];

	my $samples = $self -> {'end'} -> {$last_file};
	$samples += $offset -> {$last_file};

	my $times = $self -> {'times'};
	print "length: ", $times -> nice_time( $times -> bytes_to_seconds( $samples ) ), " ($samples bytes)\n";

	my $alltime = time;
	my $pos = $self -> {'start'} -> {$first_file};
	my %queue;
	my $read = $self -> {'read'};
	my $block_align = $self -> {'block_align'};

	my $view = $self -> {'view'};
	my $display = $self -> {'display'};

	my $view_pic = "%-10.2f\t" x $self -> {'channels'};
	my %times;

	my $out_dir = $self -> {'dirs'} -> {'out'};
	my $out_file = $self -> {'outfile'};
	my $write_details = $self -> {'write_details'};

	my( $write, $file_count );

	my $wav = new Audio::Wav;

	my $split = $self -> {'split'};

	my @out_files;

	if ( $split ) {
		$file_count ++;
		$out_file = &_split_file( $out_file, $file_count );
		$write = $wav -> write( $out_dir . '/' . $out_file . '.wav', $write_details );
		push @out_files, $write -> file_name();
	} else {
		$write = $wav -> write( $out_dir . '/' . $out_file . '.wav', $write_details );
		push @{ $self -> {'breaks'} }, 0;
	}

	$self -> {'write'} = $write;

	my $first_sig = $self -> {'first_sig'};

	my %split_pos;

	foreach my $id ( 1 .. $#$order ) {
		my $file = $order -> [$id];
		my $spl_pos = $offset -> {$file} + $first_sig -> {$file};

#		print "$id) dao: [$spl_pos] ", $times -> dao_time( $spl_pos ), "\n";

		if ( $split ) {
			$file_count ++;
			$split_pos{$spl_pos} = &_split_file( $out_file, $file_count );
		} else {
			$write -> add_cue( $spl_pos, "label ($id)", "note ($id)"  );
			push @{ $self -> {'breaks'} }, $spl_pos;
		}
	}

	while ( $pos < $samples ) {
		if ( $split && exists( $split_pos{$pos} ) ) {
			$self -> {'write'} -> finish();
			$write = $wav -> write( $out_dir . '/' . $split_pos{$pos} . '.wav', $write_details );
			$self -> {'write'} = $write;
			push @out_files, $write -> file_name();
		}
		if ( exists $ranges -> {$pos} ) {
			my $record = $ranges -> {$pos};
			my @types = keys %$record;
			die "there shouldn't be both ", join( ' & ', @types ), " in mix" if scalar( @types ) > 1;
			my $type = $types[0];
			$record = $record -> {$type};
#			print "$pos) $type\n";
			if ( $type eq 'copy' ) {
				die "there shouldn't be more than one copy at $pos in mix" if scalar( @$record ) > 1;
				my( $file, $data ) = @{ $record -> [0] };

				my $byte_time = $times -> nice_time( $times -> bytes_to_seconds( $data -> {'end'} ) );
				printf "%d) copying %d bytes from %s (%s)", $pos, $data -> {'end'} - $data -> {'start'}, $file, $byte_time;

				my $time = time;
				$pos += $self -> _copy( $file, $data );
				$time = $times -> nice_time( time - $time );
				print " (took $time)\n";
				next;
			}
			foreach my $part ( @$record ) {
				my( $file, $type, $data ) = @$part;
				my $record = &_add_queue( $pos, $type, $data );
				$type = $record -> {'type'};
				if ( exists $queue{$file} ) {
					print Data::Dumper->Dump([ $queue{$file}, $record ]);
					die "queue for $file already has an entry ($pos)" ;
				}
				$queue{$file} = $record;
				$times{$file} = time;
				$read -> {$file} -> move_to( $data -> {'start'} );
				my $byte_time = $times -> nice_time( $times -> bytes_to_seconds( $record -> {'length'} ) );
				printf "%d) starting %s on %s, %d bytes (%s)\n", $pos, $type, $file, $record -> {'length'}, $byte_time;
				$display -> new_count( $file, $type, $pos, $record -> {'length'} ) if $view;

			}
		}
		my @mix;
		my @files = keys %queue;
		foreach my $id ( 0 .. $#files ) {
			my $file = $files[$id];
			my $data = $queue{$file};
			my $values = &_get_sample( $read -> {$file}, $data );
			push @mix, $values;
			if ( $view && ! ( $pos % $view ) ) {
				$display -> progress( $pos, $file, $data -> {'type'}, $values );
			}
			$data -> {'count'} += $block_align;
			next if $data -> {'length'} > $data -> {'count'};
			$display -> finish_count( $file, $data -> {'type'} ) if $view;
			my $time = $times -> nice_time( time - $times{$file} );
			printf "%d) finishing %s on %s, %d bytes (took %s)\n", $pos, $data -> {'type'}, $file, $data -> {'length'}, $time;
			delete $queue{$file};
		}
		$self -> _mix( $pos, \@mix, $view, $view_pic );
		$pos += $block_align;
	}
	$alltime = $times -> nice_time( time - $alltime );
	print "mixing took $alltime\n";
	print join( ' - ', @out_files ), "\n";
	$self -> {'write'} -> finish();
}


sub dao_cue_file {
	my $self = shift;

	my $breaks = $self -> {'breaks'};
	my $file = $self -> {'write'} -> file_name();
	my $out_dir = $self -> {'dirs'} -> {'out'};
	my $out_file = $self -> {'outfile'};

	my $to_file = join ( '', $out_dir, '/', $out_file, '.cue' );

	$self -> {'times'} -> dao_cue_file( $breaks, $file, $to_file );
}


##################

sub _find_ranges {
	my $self = shift;
	my $offsets = $self -> {'offsets'};
	my @order = @{ $self -> {'order'} };

	my %mix;

#	my $last = 0;
	my $last = $self -> {'start'} -> { $self -> {'order'} -> [ 0 ] };

	foreach my $file ( @order ) {
#		my $start = $offsets -> {$file};
		my $start = $offsets -> {$file} + $self -> {'start'} -> {$file};
		$mix{$start} = $last if $last > $start;
#		$last = $start + $self -> {'end'} -> {$file};
		$last = $offsets -> {$file} + $self -> {'end'} -> {$file};
	}

	my $cues = $self -> {'cues'};

	my $max = 0;
	my $output;
	foreach my $file ( @order ) {
		my $offset = $offsets -> {$file};
		my $cue = $cues -> {$file};
		my $record = $cue -> {'copy'};
		my( $start, $end, $extra ) = map $record -> {$_}, qw( start end fade );
		$start += $offset;
		$end += $offset;
		my $overlaps = 0;
		my %inside;
		foreach my $over_start ( sort { $a <=> $b } keys %mix ) {
#			print "$file) test: copy( $start, $end ) over( $over_start, $mix{$over_start} )\n";
			next if $over_start > $end;
			next if $mix{$over_start} < $start;
			$overlaps ++;
			$inside{'start'} = $mix{$over_start} if $start >= $over_start;
			$inside{'end'} = $over_start if $mix{$over_start} >= $end;
#			print "overlap ", join( ' - ', %inside ), "\n";
			last if scalar( keys %inside ) == 2;
		}
		my $extra_copy;
		if ( $overlaps ==1 && scalar( keys %inside ) == 2 ) {
		} elsif ( $overlaps ) {
			my $real_start = $start;
			my $rec_start = $start - $offset;
			my $rec_end = $end - $offset;
			my( $estart, $eend ) = map exists( $inside{$_} ), qw( start end );

			if ( $estart && $eend ) {
				foreach my $key ( keys %$record ) {
					$extra_copy -> {$key} = $record -> {$key};
				}
				$record -> {'end'} = $inside{'start'} - $offset;
				$extra_copy -> {'start'} = $inside{'end'} - $offset;
				$real_start = $inside{'start'};
				$rec_start = $record -> {'end'};
				$rec_end = $extra_copy -> {'start'};

#				print "orig copy = $start - $inside{'start'}\n";
#				print "extra copy = $inside{'end'} - $end\n";
#				print "real copy = $inside{'start'} - $inside{'end'}\n";
#				print Data::Dumper->Dump([ $record ]);
#				print Data::Dumper->Dump([ $extra_copy ]);

			} elsif ( $estart ) {
				$record -> {'end'} = $inside{'start'} - $offset;
				$real_start = $inside{'start'};
				$rec_start = $record -> {'end'}
			} elsif ( $eend ) {
				$record -> {'start'} = $inside{'end'} - $offset;
				$rec_end = $record -> {'start'};
			} else {
				die "no overlaps";
			}
			push @{ $output -> { $real_start } -> {'copy'} },
					[
						$file,
						{
						'start'		=> $rec_start,
						'end'		=> $rec_end,
						'fade'		=> $extra,
						}
					] unless $rec_start == $rec_end;

		} else {
			my $copy = delete $cue -> {'copy'};
			delete $copy -> {'sub'};
			push @{ $output -> { $start } -> {'copy'} },
					[
						$file,
						$copy,
					];
		}
		foreach my $type ( keys %$cue ) {
			my( $start, $end ) = map $cue -> {$type} -> {$_}, qw( start end );
			next if ( $start == $end );
			$start += $offset;
			push @{ $output -> {$start} -> {'mix'} }, [ $file, $type, $cue -> {$type} ];
		}
		next unless defined( $extra_copy );
		next if ( $extra_copy -> {'start'} == $extra_copy -> {'end'} );
		my $exstart = $extra_copy -> {'start'} + $offset;
		push @{ $output -> {$exstart} -> {'mix'} }, [ $file, 'copy', $extra_copy ];
	}
	foreach my $start ( sort { $a <=> $b } keys %$output ) {
#		print "$start)\n";
		foreach my $type ( keys %{ $output -> {$start} } ) {
#			print "\t$type;\n";
			foreach my $record ( @{ $output -> {$start} -> {$type } } ) {
				if ( $type eq 'copy' ) {
					my( $file, $data ) = @$record;
					my( $start, $end ) = map $data -> {$_} + $offsets -> {$file}, qw( start end );
#					print "\t $file: $start - $end\n";
				} else {
					my( $file, $ftype, $data ) = @$record;
					my( $start, $end ) = map $data -> {$_} + $offsets -> {$file}, qw( start end );
#					print "\t$ftype $file: $start - $end\n";
				}
			}
		}
	}
#	print Data::Dumper->Dump([ $output ]);
#	exit;
	return $output;
}

sub _split_file {
	my $file = shift;
	my $cnt = shift;
	return $file . '_' . $cnt;
}

sub _mix {
	my $self = shift;
	my $pos = shift;
	my $data = shift;
	my $view = shift;
	my $view_pic = shift;
	my $output;
	for my $row_id ( 0 .. $#$data ) {
		my $row = $data -> [$row_id];
		for my $col_id ( 0 .. $#$row ) {
			$output -> [$col_id] += $row -> [$col_id];
		}
	}

	my $max = $self -> {'max_volume'};
	for my $col_id ( 0 .. $#$output ) {
		next unless abs( $output -> [$col_id] ) > $max;
		printf "\tnoisy %d\t%-10.2f ", $col_id, $output -> [$col_id];
		if ( $output -> [$col_id] > 0 ) {
			$output -> [$col_id] = $max;
		} else {
			$output -> [$col_id] = -$max;
		}
		print $output -> [$col_id], "\n";
	}

#	if ( $view && ! ( $pos % $view ) ) {
#		printf $view_pic . "(output)\n", @$output;
#	}
	$self -> {'write'} -> write( @$output );
}

sub _get_sample {
	my $read = shift;
	my $record = shift;
#	die Data::Dumper->Dump([ $record ]);
	my( $type, $count, $filter ) = map $record -> {$_}, qw( type count filter );
	my @data = $read -> read();
	die unless defined( @data );
	@data = &$filter( $count, @data ) unless $type eq 'copy';
	return \@data;
}

sub _add_queue {
	my $pos = shift;
	my $type = shift;
	my $data = shift;
	# $pos + $data -> {'end'},
	$type .= ' (' . $data -> {'type'} . ')' if exists( $data -> {'type'} );
	my $output =	{
			'length'	=> $data -> {'end'} - $data -> {'start'},
			'count'		=> 0,
			'type'		=> $type,
			'filter'	=> $data -> {'fade'},
			};
	return $output;
}

sub _copy {
	my $self = shift;
	my $file = shift;
	my $data = shift;
	my $read = $self -> {'read'} -> {$file};
	my $write = $self -> {'write'};
	my( $from, $to, $buffer ) = map $data -> {$_}, qw( start end fade );
	$buffer = 256 unless $buffer;
	$read -> move_to( $from );

	my $display = $self -> {'display'};
	my $view = $self -> {'view'};
	$view *= 100;
	$view -= $view % $buffer if $view;

	my $cur_type = 'copy';
	my $length = $to - $from;
	$display -> new_count( $file, $cur_type, $from, $length ) if $view;

	my $total = 0;

	while ( $total < $length ) {
		my $left = $length - $total;
		$buffer = $left unless $left > $buffer;
		my $data = $read -> read_raw( $buffer );
		last unless defined( $data );
		$write -> write_raw( $data, $buffer );
		$total += $buffer;
		next unless ( $view && ! ( $total % $view ) );
		$display -> progress( $total, $file, $cur_type );
	}
	$display -> finish_count( $file, $cur_type ) if $view;
	return $to - $from;
}

sub _copy2 {
	my $self = shift;
	my $file = shift;
	my $data = shift;
	my $read = $self -> {'read'} -> {$file};
	my $write = $self -> {'write'};
	my( $from, $to, $buffer ) = map $data -> {$_}, qw( start end fade );
	$buffer = 256 unless $buffer;
	$read -> move_to( $from );
	my $total = $to - $from;
	while ( $total > 0 ) {
		$buffer = $total unless $total > $buffer;
		my $data = $read -> read_raw( $buffer );
		last unless defined( $data );
		$write -> write_raw( $data, $buffer );
		$total -= $buffer;
	}
	return $to - $from;
}

1;

