$| = 1;

my $out_dir = 'test_output';

unless ( -d $out_dir ) {
	mkdir( $out_dir, 0777 ) ||
		die "unable to make test output directory '$out_dir' - ($!)";
}

my %mods	= (
		  'mix'		=> 'Audio::Mix',
		  'wav'		=> 'Audio::Wav',
		  'cooledit'	=> 'Audio::CoolEdit',
		  'tools'	=> 'Audio::Tools',
		  'tk'		=> 'TK',
		  );

my $tests = 4;

my %present;
foreach my $type ( keys %mods ) {
	$present{$type} = eval "require $mods{$type}";
}
$tests ++ if $present{'cooledit'};

print "1..$tests\n";

my $cnt;
foreach $type ( qw( mix tools wav ) ) {
	$cnt ++;
	unless ( $present{$type} ) {
		print "not ok $cnt, You'll need to install $mods{$type} first\n";
		die;
	} else {
		print "ok $cnt, $mods{$type} loadable\n";
	}
}

require 'makewavs.pl';
&build( $out_dir );

my @installed = qw( wav );

if ( $present{'cooledit'} || $present{'tk'} ) {
	my $installed = join( ' and ', map( $mods{$_}, grep $present{$_}, qw( tk cooledit ) ) );
	print "excellent, you've got $installed installed.\n";
	unshift @installed, 'cooledit' if $present{'cooledit'};
}

my $settings =	{
		'out_dir'	=> $out_dir,
		'hints'		=> {
					'dir'	=> $out_dir,
					'mode'	=> 'write',
			   	   },
		'fade_time'	=> 15,
		'default_fade'	=> 'trig',
		};

my $xfade = 	{
		'read_files'	=> [ map $out_dir . '/' . $_ . '.wav', 1, 2 ],
		'out_file'	=> 'xfade',
		'dao_file'	=> 1,
		};

my $wav = Audio::Mix -> new( $settings );

foreach my $type ( @installed ) {
	$cnt ++;
	print "\ntesting with $mods{$type}....\n";
	$xfade -> {'out_type'} = $type;
	$wav -> mix( $xfade );
	$xfade -> {'dao_file'} = 0;
	delete $settings -> {'hints'} -> {'mode'};
	print "ok $cnt\n";
}

