package Audio::Mix::XFade;

use strict;
use DirHandle;
use Audio::Mix::XFade::Analyse;

my @base_class = qw( Audio Mix XFade );

my %outputs =	(
			'cooledit'	=> 'CoolEdit',
			'wav'		=> 'Wav',
		);

sub new {
	my $class = shift;
	my %settings = @_;

	if ( exists $settings{'read_dir'} ) {
		$settings{'files'} = &_get_files( $settings{'read_dir'} );
	} elsif ( exists $settings{'read_files'} ) {
		$settings{'files'} = $settings{'read_files'};
	}

	my @settings = qw( dirs files outfile split write_to fades hints );

	my $settings = { map { $_ => $settings{$_} } @settings };

	my $self =	{
			'settings'	=> $settings,
			'analyse'	=> new Audio::Mix::XFade::Analyse $settings,
			};
	bless $self, $class;
	return $self;
}

sub mix {
	my $self = shift;
	my $write_mod = $outputs{ $self -> {'settings'} -> {'write_to'} };
	require join '/', @base_class, $write_mod . '.pm';
	my( $settings, $analyse ) = map $self -> {$_}, qw( settings analyse );
	my $mod_name = join '::', @base_class, $write_mod;
	my $write = $mod_name -> new( $settings, $analyse );
	$self -> {'write'} = $write;
	$write -> mix();
}

sub dao_cue_file {
	my $self = shift;
	$self -> {'write'} -> dao_cue_file();
}

sub _get_files {
	my $dir = shift;
	use DirHandle;
	my $d = new DirHandle $dir;
	my @output;
	if (defined $d) {
		my $line;
		while ( defined( $line = $d->read) ) {
			next if $line =~ /^\.{1,2}$/;
			next unless $line =~ /\.wav$/;
			push @output, $dir . '/' . $line;
		}
		undef $d;
	}
#	die join( "\n", @output );
	return \@output;
}

1;

