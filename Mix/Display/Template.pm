package Audio::Mix::Display::Template;

my $border_width = 10;

my @order = qw( file function pc eta samp_l samp_r );
my %titles =	(
			'file'		=> 'File',
			'function'	=> 'Function',
			'pc'		=> '%',
			'eta'		=> 'ETA',
			'samp_l'	=> 'Left',
			'samp_r'	=> 'Right',
		);

my %widths =	(
			'file'		=> 80,
			'function'	=> 100,
			'pc'		=> 60,
			'eta'		=> 60,
			'samp_l'	=> 120,
			'samp_r'	=> 120,
		);


sub new {
	my $class = shift;
	my $self =	{
				'tk'		=> shift,
			};
	my( $function_data_1, $file_data_1, $pc_data_1, $eta_data_1, $samp_l_1, $samp_r_1 );
	my( $function_data_2, $file_data_2, $pc_data_2, $eta_data_2, $samp_l_2, $samp_r_2 );
	my $data_ref =	[
				{
					'function'	=> \$function_data_1,
					'file'		=> \$file_data_1,
					'pc'		=> \$pc_data_1,
					'eta'		=> \$eta_data_1,
					'samp_l'	=> \$samp_l_1,
					'samp_r'	=> \$samp_r_1,
				},
				{
					'function'	=> \$function_data_2,
					'file'		=> \$file_data_2,
					'pc'		=> \$pc_data_2,
					'eta'		=> \$eta_data_2,
					'samp_l'	=> \$samp_l_2,
					'samp_r'	=> \$samp_r_2,
				},
			];
	$self -> {'data_ref'} = $data_ref;
	bless $self, $class;
	$self -> call();
	return $self;
}

sub get_data_ref {
	my $self = shift;
	return $self -> {'data_ref'};
}

sub get_data_order {
	my $self = shift;
	return [ @order ];
}

sub call {
	my $self = shift;
	my $tk = $self -> {'tk'};
	my $data = $self -> {'data_ref'};

	my $tk_titles;

	foreach my $title ( @order ) {
		$tk_titles -> {$title} =
			$tk -> Label	(
					'-text'	=> $titles{$title},
					);
	}

	my $tk_data;

	for my $row ( 0, 1 ) {
		foreach my $title ( @order ) {
			$tk_data -> [$row] -> {$title} =
				$tk -> Label	(
						'-textvariable'	=> $data -> [$row] -> {$title},
						);
		}
	}


	my $row = 1;

	foreach my $col ( 0 .. $#order ) {
		$tk_titles -> { $order[$col] }
			-> grid	(
				'-in'		=> $tk,
				'-column'	=> $col + 1,
				'-row'		=> $row,
				);
	}


	for my $row_id ( 0, 1 ) {
		$row ++;
		foreach my $col ( 0 .. $#order ) {
			$tk_data -> [$row_id] -> { $order[$col] }
				-> grid	(
					'-in'		=> $tk,
					'-column'	=> $col + 1,
					'-row'		=> $row,
					);
		}
	}

	# Resize behavior management

	for my $grid_row ( 1 .. $row ) {
		$tk -> gridRowconfigure
			(
			$grid_row,
			-weight		=> 0,
			-minsize	=> 40,
			);
	}

	foreach my $grid_col ( 0 .. $#order ) {
		$tk -> gridColumnconfigure
			(
			$grid_col + 1,
			-weight		=> 0,
			-minsize	=> $widths{ $order[$grid_col] },
			);
	}
}

1;


