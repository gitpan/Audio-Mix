package Audio::Mix::Display;

use strict;

my $tk_ok = eval( 'require TK' );
my $tk_menu_ok = eval( 'require TK::Menu' );
require Audio::Mix::Display::Template;

sub new {
	my $class = shift;
	return undef unless ( $tk_ok && $tk_menu_ok );
	my $self =	{
				'times'		=> shift,
				'channels'	=> shift,
			};
	bless $self, $class;
	$self -> _init();
	return $self;
}

sub _init {
	my $self = shift;
	my $top = MainWindow -> new();
	$top -> title( 'Cross Fade' );
	$self -> {'window'} = $top;
	my $template = new Audio::Mix::Display::Template $top;
	$self -> {'template'} = $template;
	$self -> {'data_ref'} = $template -> get_data_ref();
	$self -> {'keys'} = $template -> get_data_order();
}

sub new_count {
	my $self = shift;
	my $file = shift;
	my $function = shift;
	my $pos = shift;
	my $length = shift;
	my $record =	{
				'start'		=> $pos,
				'length'	=> $length,
				'time'		=> time,
			};
	$self -> {'progs'} -> {$file} -> {$function} = $record;
	push @{ $self -> {'prog_ids'} }, join( ':', $file, $function );
}

sub progress {
	my $self = shift;
	my $pos = shift;
	my $file = shift;
	my $function = shift;
	my $values = shift;

	my $data = $self -> {'progs'} -> {$file} -> {$function};

	$pos -= $data -> {'start'};
	my $length = $data -> {'length'};

	my $pc = sprintf( '%6.2f', ( $pos / $length ) * 100 );

	my $eta = '';
	if ( $pos ) {
		$eta = time - $data -> {'time'};
		$eta = ( $eta / $pos ) * ( $length - $pos );
		$eta = $self -> {'times'} -> nice_time( $eta, 1 );
	}
	my %record =	(
			'file'		=> $file,
			'function'	=> $function,
			'pc'		=> $pc,
			'eta'		=> $eta,
			);

	my @chan_name = qw( l r );
	if ( ref $values ) {
		for my $channel ( 0 .. $self -> {'channels'} - 1 ) {
			$record{ 'samp_' . $chan_name[$channel] } = int( $values -> [$channel] );
			last if $channel == 1;
		}
	}
	$self -> _write_record( $file, $function, \%record );
}

sub finish_count {
	my $self = shift;
	my $file = shift;
	my $function = shift;
	my $id = join( ':', $file, $function );
	my %record =	(
			'file'		=> '',
			'function'	=> '',
			'pc'		=> '',
			'eta'		=> '',
			);

	my @chan_name = qw( l r );
	for my $channel ( 0 .. $self -> {'channels'} - 1 ) {
		$record{ 'samp_' . $chan_name[$channel] } = '';
		last if $channel == 1;
	}
	$self -> _write_record( $file, $function, \%record );
	delete( $self -> {'progs'} -> {$file} -> {$function} );
	@{ $self -> {'prog_ids'} } = grep  $_ ne $id, @{ $self -> {'prog_ids'} };
}

sub _write_record {
	my $self = shift;
	my $file = shift;
	my $function = shift;
	my $record = shift;
	my $id;
	my $id_name = join( ':', $file, $function );
	my $progs = $self -> {'prog_ids'};
	foreach my $cur_id ( 0 .. $#$progs ) {
		next unless $progs -> [$cur_id] eq $id_name;
		$id = $cur_id;
		last;
	}
	unless ( defined $id ) {
		warn "no id ($id_name)\n";
		return;
	}
	foreach my $key ( keys %$record ) {
#		print"id[$id] key[$key] = ", $record -> {$key}, "\n";
		${ $self -> {'data_ref'} -> [$id] -> {$key} } = $record -> {$key};
	}
	$self -> {'window'} -> update();
}


1;
