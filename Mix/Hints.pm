package Audio::Mix::Hints;

use strict;
use File::Basename;
use FileHandle;

my @cue_fields = qw( start end first_sig last_sig fade_in fade_in_type fade_out fade_out_type );
my @info_fields = qw( band song bpm key );

sub new {
	my $class = shift;
	my $self =	{
			'dir'	=> shift,
			'read'	=> shift,
			'times'	=> shift,
			};
	$self -> {'file'} = $self -> {'read'} -> file_name();
	bless $self, $class;
	return $self;
}

sub read {
	my $self = shift;
	my $cues = shift;
	my $info = shift;
	print "in: ", Data::Dumper->Dump( [ $cues, $info ] );
	my $out_file = $self -> _hint_file( $self -> {'file'} );
	my $fh = new FileHandle;
	unless ( $fh -> open( "< $out_file" ) ) {
		die "unable to read hint file '$out_file'";
	}
	print "reading hint $out_file\n";
	my %allowed = map { $_ => 1 } ( @cue_fields, @info_fields );
	my %info = map { $_ => 1 } @info_fields;
	my $times = $self -> {'times'};
#	my $cues = {};
#	my $info = {};
	while ( <$fh> ) {
		chomp;
		my( $key, $val ) = split /\t/;
		next unless $val;
		print "$key = $val\n";
		if ( exists $allowed{$key} ) {
			if ( exists $info{$key} ) {
				$info -> {$key} = $val;
			} else {
				$val = $times -> samples_to_bytes( $val ) unless $key =~ /_type$/;
				$cues -> {$key} = $val;
			}
		} else {
			warn "unrecognised key '$key'\n";
		}
	}
        $fh -> close();
	print "out: ", Data::Dumper->Dump( [ $cues, $info ] );
	return;
	return	{
		'cues'	=> $cues,
		'info'	=> $info,
		};
#exit;
}

sub save {
	my $self = shift;
	my $info = shift;
	my $cues = shift;
	my $out_file = $self -> _hint_file( $self -> {'file'} );
	my $fh = new FileHandle;
	unless ( $fh -> open( "> $out_file" ) ) {
		die "unable to write hint file '$out_file'";
	}
	print "writing hint $out_file\n";
	my $times = $self -> {'times'};
	foreach my $key ( @info_fields ) {
		$self -> _write_line( $fh, $key, $info -> {$key} );
	}
	foreach my $key ( @cue_fields ) {
		my $value = $cues -> {$key};
		unless ( $key =~ /_type$/ ) {
			$value = $times -> bytes_to_samples( $value );
		}
		$self -> _write_line( $fh, $key, $value );
	}
        $fh -> close();
#	print Data::Dumper->Dump( [ $cues ] );
}

sub _write_line {
	my $self = shift;
	my $fh = shift;
	my $key = shift;
	my $value = shift;
	$key = defined( $key ) ? $key : '';
	$value = defined( $value ) ? $value : '';
	print $fh join( "\t", $key, $value ), "\n";
}

sub _hint_file {
	my $self = shift;
	my $file = shift;
	my $base = basename( $file, '.wav' );
	return join( '/', $self -> {'dir'}, $base . '.hint' );
}

1;
