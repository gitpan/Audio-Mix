package Audio::Mix;

use strict;
use vars qw( $VERSION );

$VERSION = '0.01';

=head1 NAME

Audio::Mix - Module for fading cross-fading wav audio files.

=head1 SYNOPSIS

	my $settings =	{
			'out_dir'	=> '.',
			'hints'		=> {
					   'dir'	=> '.',
					    'mode'	=> 'write',
					   },
			'fade_time'	=> 15,
			'default_fade'	=> 'linear',
			};

	my $wav = Audio::Mix -> new( $settings );

	my $xfade = 	{
			'out_type'	=> 'cooledit',
			'read_dir'	=> './t',
			'out_file'	=> 'xfade',
			'dao_file'	=> 1,
			};

	$wav -> mix( $xfade );

=head1 DESCRIPTION

=head2 Perl Wav/ CoolEdit Fader/ Cross-Fader

The purpose of this module is to provide a way to apply
fades to uncompressed Microsoft .wav files. Not being a
c programmer, the fades are done completely in perl,
making a minutes fade on a stereo  44.1 Khz, 16bit file
take a considerable amount of time. The primary reason
I wrote this module was because I needed a programmatic
way to mix songs together for subsequent burning to a
CDR. After spending many hours watching countdowns
while my perl loop faded files in & out I contacted
Syntrillium, makers of the excellent multitrack sound
editor 'Cooledit Pro' asking for details of their file
format, so I could have the perl program read the
attributes of each .wav file, sort them by tempo,
arrange the fading curves and write all this to a small
Cooledit 'session' file for subsequent preview/
tweaking. I personally use the Cooledit mode for a
number of reasons;

=over 4

* You can listen to the results in minutes rather
than hours.

* You can view all the waveforms together and
visually see the non-destructive fades that will be
applied

* It handles clipping (when the digital volume
becomes larger than the bit size will allow), my
program just warns you when it happens and does
nothing about it :-(

=back

Among the reasons I have left the perl .wav mixing
routines is for people who may be using a non mswin32
platform or cannot justify the price of Cooledit. Also
I'm kind of hoping that a c whizz will become
interested and contact me about writing a super cool c
mixing engine in this curious XS thing I've been
hearing so much about :-) While on the subject of
different platforms, I pretty sure that this version
will not work on big endian processors as I'm not doing
anything about network orders etc yet, as it started to
make my head hurt!
(L<Audio::Tools::ByteOrder>)

=head1 Why?

The concept behind this module is that each .wav file
can be marked up to give the arrangement decider (for
want of a better name) clues as to the best way to mix
a song into the final output. You can start out marking
up the actual file with cuepoints and at a later stage
when tweaking the mix you can place a hint file in a
given directory and these settings will take precedence
over the settings marked up in the .wav file. I'm
planning to add a feature that will encode the
information in the hint file into the .wav file. This
should be able to be done fairly quickly as this
information usually resides after the sound data block.

The Cross Fader is given either an input directory
that it collects its .wav files from or a list of fully
qualified paths.

The two methods for marking up files are;

=head1 Markup Methods

=head2 Cuepoints within the .wav file.

Markups should be entered with the command in the name
field & the option in the description field. I've only
used cooledit to mark these files so I'm not sure how
the program would behave with cuepoints created in
another audio editing program.

To edit cuepoints (in cooledit) choose

	View -> Cue Edit

=over 4

* type the command in the Name & the option in
Description.

=back

Within a .wav file, Cooledit uses the CUE block to define
offsets for each cue, but it uses LIST block to store the
name & description information. This LIST block type is
known as an Associated Data List (adtl). This method of
encoding cue point names & descriptions is not universally
accepted as a good thing, but I couldn't find an alternative
method.

=head2 Entries in a hint file.

If a correspondingly named .hint file exists in the
hints directory then this information will be used in
preference to the markups within the .wav file. You can
set the hint directory to be the same as the .wav input
directory but this has little use when dealing with
read only sources (such as CDR).

The hint file should have each command on a separate
line with the option on the same line after a tab. All
times should be in sample format, offset from 0 (being
the start of the file).

Hints can also exist in the .wav input directory, but
if this is the case they have lower priority than the
ones in the hint directory.

=head1 Markup Types.

=head2 Start/ End Points

=over 4

B<command:> start/ end

B<options:> none

=back

These markers determine at which point the song will
start/ end. Fades are started/ finished from these
points

=head2 Significant points

=over 4

B<command:> sig

B<options:> first/ last

=back

A significant point in a song will be used as the
position the next/ previous song aligns it's first/
last point to. In general it's good practice to try
and make these points sit at the first beat of the
bar (or at least on a beat). In this way even if two
songs tempos do not match exactly at the significant
point for each song it should fall on the same beat.
I've found that significant points sound good at the
centre of a fade in/ out

=head2 Fades

See L<Audio::Tools::Fades>

=over 4

B<command:> fade_in/ fade_out

B<options:> linear/ trig/ invtrig/ exp/ invexp

=back

Currently the module only supports a fade in from
either the start of the file or from a start tag or a
fade out to the end of the file or a end tag.

The different fade types are;

=over 4

* linear - Smooth linear fade

* trig/ invtrig - Trigonomic fade. My favourite. looks
suspiciously like a quarter of a circle. Inv is the
inverse, i.e. starts slowly, gets louder/ quiter
the nearer the end it gets

* exp/ invexp - Exponential fade. An extreme fade that
follows x squared. Gets loud/ quite quickly and
finishes slowly. invexp as above

=back

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

L<Audio::Tools::ByteOrder>

L<Audio::Tools::Fades>

L<Audio::Wav>

L<Audio::CoolEdit>

=head1 METHODS

=head2 new

Returns a blessed Audio::Mix object.

	my $settings =	{
			'out_dir'	=> '.',
			'fade_time'	=> 15,
			'default_fade'	=> 'linear',
			'hints'		=> {
					   'dir'	=> '.',
					   'mode'	=> 'write',
					   },
			};

	my $wav = Audio::Mix -> new( $settings );

Where; (all are optional)

=over 4

out_dir		=> the directory the mix will be created in.

fade_time	=> the default length of a fade in seconds.

default_fade	=> the default fade type

auto_fade	=> if this is true (1) then unmarked-up file will have the default
		   fade applied for the default length. The significant point will
		   be in the centre.

hints		=> a reference to a hash containing;

	{
	dir	=> path to read hints from
	mode	=> read, write or blank for neither
	}

=back

=cut

sub new {
	my $class = shift;
	my $settings = shift;
	my $dirs =	{
			'out'		=> &_key_exist( $settings, 'out_dir', '.' ),
			};

	my $fades =	{
			'time'		=> &_key_exist( $settings, 'fade_time', 10 ),
			'type'		=> &_key_exist( $settings, 'default_fade', 'linear' ), #'trig'
			'auto'		=> &_key_exist( $settings, 'auto_fade', 1 ),
			};

	my $self =	{
			'dirs'		=> $dirs,
			'fades'		=> $fades,
			'hints'		=> &_key_exist( $settings, 'hints', { } ),
			};
	bless $self, $class;
	return $self;
}

=head2 mix

Creates a mix of a number of given files.

	my $xfade = 	{
			'out_type'	=> 'cooledit',
			'read_dir'	=> './t',
			'out_file'	=> 'xfade',
			'dao_file'	=> 1,
			};

	$wav -> mix( $xfade );

Where; (* are optional)
- You should have either read_dir or read_files

=over 4

out_type*	=> either cooledit or wav (so far).

read_dir*	=> a directory where the source wav files can be found.

read_files*	=> a reference to an array of full paths to source wav files.

out_file*	=> the filename to write to (without extension), defaults to 'mix'.

dao_file*	=> 1 to write a Goldenhawk cue file (see Audio::Tools::Time).

=back

=cut

sub mix {
	my $self = shift;
	my $settings = shift;
	require Audio::Mix::XFade;
	my %settings =	(
				'dirs'			=> $self -> {'dirs'},
				'fades'			=> $self -> {'fades'},
				'hints'			=> $self -> {'hints'},
				'outfile'		=> &_key_exist( $settings, 'out_file', 'mix' ),
				'split'			=> 0,
				'write_to'		=> &_key_exist( $settings, 'out_type', 'wav' ),
			);
	if ( exists $settings -> {'read_dir'} ) {
		$settings{'read_dir'} = $settings -> {'read_dir'};
	} elsif ( exists $settings -> {'read_files'} ) {
		$settings{'read_files'} = $settings -> {'read_files'};
	} else {
		die <<HERE
you have to either specify;
	read_files	a reference to an array of wav filenames
	read_dir	a directory to collect wav files from
HERE
	}

	my $xfade = new Audio::Mix::XFade %settings;
	$xfade -> mix();
	$xfade -> dao_cue_file() if &_key_exist( $settings, 'dao_file', 0 )
}

sub _key_exist {
	my $hash = shift;
	my $key = shift;
	my $default = shift;
	return exists( $hash -> {$key} ) ? $hash -> {$key} : $default;
}

1;

