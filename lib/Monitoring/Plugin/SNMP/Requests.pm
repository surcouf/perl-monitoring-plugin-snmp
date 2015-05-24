#
# Monitoring::Plugin::SNMP::Requests - perl module providing some methods
#   for nagios SNMP plugins 
#
package Monitoring::Plugin::SNMP::Requests;

use strict;
use warnings;

use Params::Validate		qw/ validate /;

use Data::Dumper;

use Switch;

=head1 NAME

Monitoring::Plugin::SNMP::Requests - perl module providing some methods
for nagios SNMP plugins 

=head1 VERSION

Version 0.01

=cut

our $VERSION = $Monitoring::Plugin::SNMP::VERSION;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

=head1 EXPORT

A list of functions that can be exported.

=cut

use Exporter;
our @ISA = qw/ Exporter /;
our @EXPORT	= qw/ 
		get_request
		get_list
		get_table
		get_named_table
		get_indexed_table
		get_index_by_name
		get_index_by_foreign_index
		get_table_by_index
		get_named_table_by_index
		get_table_by_name
		get_named_table_by_name
		get_oids_list
		get_short_units_of
		get_units_of
		get_type_of
		check_for_errors
        /;


=head1 FUNCTIONS

=head2 get_request

Gets the named variable and returns its value. If no value is returned,
C<get_request()> will try to retrieve the same C<name> using '0' as index and
return its first value. Thus, for convenience, 

	$s->get_request( oid => 'sysDescr' )

..should be the same as:

	$s->get_request( oid => 'sysDescr', index => 0 )

Numbered OIDs are fine, too, with or without a leading dot:

	$s->get_request( oid => '1.3.6.1.2.1.1.1.0' )

C<SNMP::mapEnum()> is automatically used on the result.

=cut

sub get_request {
	my $self 			= shift;
   	my %params = validate( @_, {
				oid 	=> 1,
				index	=> 0,
			},
		);
	
	my $ref				= ref $params{'oid'};
	my $vars 			= undef;
	
	#
	# Single OID 
	#
	if ( $ref eq '' ) {

		my $result 		= undef;

		if ( defined( $params{'index'} ) ) {
			$params{'oid'} .= ".". $params{'index'};
		}

		my $indexes = get_indexes_of( $params{'oid'} );
		if ( not defined( $params{'index'} ) 
			and not defined( $indexes ) ) {
			$result = $self->get_request(
						oid	=>	$params{'oid'},
						index	=>	0,
					);
		} 
		else {
			$result = $self->session->get( $params{'oid'} );
		}

		$self->check_for_errors( 
				result	=>	$result,
				oid	=>	$params{'oid'},
			);

		my $enum = SNMP::mapEnum( $params{'oid'}, $result );

		return defined $enum ? $enum : $result;

	}
	#
	# List of multiples OID
	#
	elsif ( $ref eq 'ARRAY' ) {

		my @results	= $self->get_oids_list(
						oid		=> $params{'oid'},
						index	=> $params{'index'},
					);

		return wantarray ? @results : \@results;
	}
	#
	# List of multiples named OID
	#
	elsif ( $ref eq 'HASH' ) {
		my %oid_to_name = reverse %{$params{'oid'}};
		my @oids        = keys %oid_to_name;
		
		my @results	= $self->get_oids_list(
						oid		=> \@oids,
						index	=> $params{'index'},
					);
		my @output;
		foreach my $row (@results) {
			my %data = ();
			for ( my $i = 0; $i < @oids; $i++ ) {
				$data{ $oid_to_name{ $oids[$i] } } = $row->[$i];
			}
			push @output, \%data;
		}

		return wantarray ? @output : \@output;
	}
	else {
		#FIXME
		$self->nagios_die( "Unknown vars for get_request ($ref))." );
	}
}

=head2 get_list( $oid )

Returns leaves of the given OID.

If called in array context, returns an array. If called in scalar context,
returns an array reference.

=cut

sub get_list {
    my ( $self, $oid ) = @_;

    my @table = $self->get_table($oid);
    
	my @output = map { $_->[0] } @table;
    
	return wantarray ? @output : \@output;
}

=head2 get_table( @oids )

Given a list of OIDs, this will return a list of lists of all of the values of
the table.

For example, to get a list of all known network interfaces on a machine and
their status:

	$s->get_table('ifDescr', 'ifOperStatus')

Would return something like the following:

	[ 'lo',   'up'   ], 
	[ 'eth0', 'down' ], 
	[ 'eth1', 'up'   ],
	[ 'sit0', 'down' ]

If called in array context, returns an array (of arrays). If called in scalar
context, returns an array reference.

=cut

sub get_table {
	my $self		= shift;
	my @oids		= @_;

	my @output;

	my $oid_table = get_parent_oid( $oids[0] );

	my $indexed_table = $self->get_indexed_table(
			base		=> $oid_table,
			oids		=> \@oids,
			noindexes	=> 1,
		);
	foreach my $line ( sort { $a <=> $b } keys %$indexed_table ) {
		my $hash = $$indexed_table{ $line };
		my @device;
		foreach my $key ( keys %$hash ) {
			push @device, $$hash{ $key };
		}
		push @output, [@device];
	}

	return wantarray ? @output : \@output;
}

=head2 get_named_table( %oids_by_alias )

Like L<get_table>, but lets you rename ugly OID names on the fly.  To get
a list of all known network interfaces on a machine and their status:

	$s->get_named_table( name => 'ifDescr', status => 'ifOperStatus' )

Would return something like the following:

        {   
            status => 'up',
            name   => 'lo'
        },
        {
            status => 'down',
            name   => 'eth0'
        },
        {
            status => 'up',
            name   => 'eth1'
        },
        {
            status => 'down',
            name   => 'sit0'
        }

If called in array context, returns an array (of hashes). If called in scalar
context, returns an array reference.

=cut

sub get_named_table {
	my $self        = shift;
	my %oid_to_name = reverse @_;
	my @oids        = keys %oid_to_name;

	# remap table so it's a list of hashes instead of a list of lists
	my @table = $self->get_table( @oids );

	my @output;
	foreach my $row (@table) {
		my %data = ();
		for ( my $i = 0; $i < @oids; $i++ ) {
			$data{ $oid_to_name{ $oids[$i] } } = $row->[$i];
		}
		push @output, \%data;
	}

	return wantarray ? @output : \@output;
}

=head2 get_indexed_table

Given a table OID, this will return a HASH reference of all of the values of
the table.
A ARRAY reference to a list of OID can be optionally passed. Without this list, ALL
accessibles OID of the table will be returned.

For example, to get a list of all known network interfaces on a machine:

	$s->get_indexed_table(
    			base	=> 'ifTable',
			oids	=> [ 'ifDescr', 'ifOperStatus' ],
		);

Would return something like the following:

	'1' => {
		'ifDescr' => 'lo',
		'ifIndex' => '1',
		'ifOperStatus' => 'up',
	},
	'2' => {
		'ifDescr' => 'eth0',
		'ifIndex' => '2',
		'ifOperStatus' => 'up',
	},

This method is based upon SNMP::Session::gettable() and can support following 
options:
   - columns: to only specify some columns (like previous example). This 
      option is added by using 'oids' option,
   - nogetbulk, automatically added when using SNMPv1,
   - noindexes, add using eponym parameter noindexes.

Note: table indexes are automatically added by the called method gettable().

=cut

sub get_indexed_table {
	my $self	= shift;
	my %params	= validate( @_, {
				base		=> 1,
				oids		=> 0,
				noindexes	=> 0,
			},
		);
	my %options;
	my $table	= undef;

	#
	# Don't add indexes OID to return HASH. Will be faster.
	#
	if ( defined( $params{'noindexes'} ) ) {
		$options{'noindexes'} = 1;
	}
	#
	# Fix gettable parse_indexes bug from 5.2.2
	#
	if ( $SNMP::VERSION lt 5.0300 ) {
		$options{'noindexes'} = 1;
	}

	#
	# Don't use GETBULK request with SNMPv1.
	#
	if ( defined( $self->opts->v1 ) ) {
		$options{'nogetbulk'} = 1;
	}

	#
	# Request only specified OID.
	#
	if ( defined( $params{'oids'} ) ) {
		$options{'columns'} = $params{'oids'};
	}

	$table = $self->session->gettable(
			$params{'base'},
			%options,
		);

	#
	# Check for any Net-SNMP errors
	#
	if ( scalar(keys(%$table)) == 0 ) {
		$self->check_for_errors(
				oid	=>	$params{'base'},
			);
	}

	return $table;
}

=head2 get_index_by_name

Use L<get_indexed_table> to search instance of a SNMP table with his name.

Regulars expressions can be used by adding 'regexp' boolean parameter.

This following example:

	$s->get_index_by_name( 
				name => 'eth0', 
				oid_names => 'ifDescr', 
			);

Would return a ARRAY like the following:

	[ 1 ]
	

=cut

sub get_index_by_name {
	my $self	= shift;
	my %params = validate( @_, {
				name		=> 1, 
				oid_names	=> 1, 
				oid_table	=> 0, 
				regexp		=> 0,
			},
		);

	my @oids;
	my @index;

	my $oid_table = $params{'oid_table'};
	if ( not defined( $oid_table ) ) {
		$oid_table = get_parent_oid( $params{'oid_names'} );
	}
	
	if ( defined( $oid_table ) ) {

		push @oids, $params{'oid_names'};

		my $indexed_table = $self->get_indexed_table(
					base		=> $oid_table,
					oids		=> \@oids,
					noindexes	=> 1,
				);

		foreach my $line ( sort { $a <=> $b } keys %$indexed_table ) {
			my $oid_name = $$indexed_table{$line}{ $params{'oid_names'} };

			$oid_name =~ s/^"(.*)"$/$1/;

			# Regexp matching
			if ( defined( $self->opts->regexp ) 
				or defined( $params{'regexp'} ) ) {
				if ( $oid_name =~ /$params{'name'}/ ) {
					push @index, $line;
				}
			}
			# Equality matching
			else {
				if ( $oid_name eq $params{'name'} ) {
					push @index, $line;
				}
			}
		}
	}
	else {
		$self->nagios_die(
				" Perhaps ". $params{'oid_names'} 
				." isn't an OID of a valid SNMP table.",
			);
	}

	if ( scalar( @index ) eq 0 ) {
		my $output = "No such instance for "
					. $params{'oid_names'}; #FIXME
		if ( $params{'oid_names'} !~ /\.\d+/ ) {
			$output .= " (". &SNMP::translateObj($params{'oid_names'}) .") ";
		}
		$output .= "with name like '". $params{'name'} ."'";
		$self->nagios_die( $output );
	}

	return wantarray ? @index : \@index;
}

=head2 get_table_by_index(
				oids	=> \@oidlist,
				index	=> $index,
			)

Like L<get_table>, but add indexe attribut to each Varbinds and this will 
return a list of lists of selected values of the table.

For example, to get a list of all known network interfaces on a machine and
their status:

	$s->get_table_by_index(
			oids 	=> ['ifDescr', 'ifOperStatus'],
			index	=> 1,2
		)

Would return something like the following:

	[
		[ 'eth0', 'down' ], 
		[ 'eth1', 'up' ], 
	],

If called in array context, returns an array (of arrays). If called in scalar
context, returns an array reference.

=cut

sub get_table_by_index {
	my $self	= shift;
   	my %params	= validate( @_, {
				oids 	=> 1,
				index	=> 1,
			},
		);
	my @output = ();
	my @results = ();

	
 	foreach my $index ( @{$params{'index'}} ) {
		my @map = map { 
					[ 
						$_, 
						$index,
					] 
				} @{$params{'oids'}};

		my $vars = SNMP::VarList->new( 
					@map,
			);
		my @results;

		foreach my $var ( @{$vars} ) {
			push @results, $self->session->get($var);
			$self->check_for_errors( 
					result	=>	$var->val,
					oid	=>	$var->name,
				);
		}
		push @output, [@results];
	}

	return wantarray ? @output : \@output;
}

=head2 get_tables_by_array_of_index

=cut

sub get_tables_by_array_of_index {
	my $self	= shift;
	my %params	= validate( @_, {
				oids	=>	1,
				index	=>	1,
			},
		);
	my @valid_indexes = ();

	my $oid_table = get_parent_oid( $params{'oids'}[0] );

	my $indexed_table = $self->get_indexed_table (
				base		=> $oid_table,
				oids		=> $params{'oids'},
				noindexes	=> 1,
		);

	foreach my $given_index ( sort { $a <=> $b } keys %$indexed_table ) {
		foreach my $required_index ( @{ $params{'index'} }) {
			if ( $given_index ne $required_index ) {
				push @valid_indexes, $given_index;
			}
		}
	}

	return wantarray ? @valid_indexes : \@valid_indexes;
}

=head2 get_named_table_by_index

Like L<get_named_table>, but depends upon L<get_table_by_index> and need an
index (found with L<"get_index_by_name"> for example). This method will lets
you rename ugly OID names on the fly.
To get a list of all known network interfaces on a machine and their status by index:

	$s->get_named_table_by_index( 
			oids	=> { name => 'ifDescr', status => 'ifOperStatus' },
			index	=> 2,
		);

Would return something like the following:

        {
            status => 'up',
            name   => 'eth1'
        },

If called in array context, returns an array (of hashes). If called in scalar
context, returns an array reference.

=cut

sub get_named_table_by_index {
	my $self	= shift;
	my %params = validate( @_, {
				index	=> 1, 
				oids	=> 1, 
			},
		);
	my @output;

	my %oid_to_name	= reverse %{$params{'oids'}};
	my @oids	= keys %oid_to_name;

	# remap table so it's a list of hashes instead of a list of lists
	my @table = $self->get_table_by_index(
			index	=>	$params{'index'},
			oids	=>	\@oids,
		 );

	foreach my $oid_table (@table) {
		my %results;

		foreach my $oid (@{$oid_table}) {
			for ( my $i = 0; $i < @oids; $i++ ) {
				$results{ $oid_to_name{ $oids[$i] } } = $$oid_table[$i];
			}
		}

		push @output, \%results;
	}

	return wantarray ? @output : \@output;
}

=head2 get_table_by_name

Depending upon L<get_index_by_name> and L<get_table_by_index>, this method will
use both to retreive index from a name and retreive the SNMP table for on instance.

To get a list of all known network interfaces on a machine and their status by index:

	$s->get_table_by_name( 
    			name => 'eth0',
			oid_names => 'ifDescr',
			oids	=> [ 'ifDescr', 'ifOperStatus' ],
		);

Would return something like the following:

	[ 'eth0', 'down' ], 

If called in array context, returns an array. If called in scalar context, 
returns an array reference.

=cut

sub get_table_by_name {
	my $self	= shift;
	my %params	= validate( @_, {
				name		=> 1, 
				oid_names	=> 1,
				oids		=> 1, 
				regexp		=> 0,
			},
		);

	my $index = $self->get_index_by_name(
			name		=>	$params{'name'},
			oid_names	=>	$params{'oid_names'},
			regexp		=>	$params{'regexp'},
		);

	my @output = $self->get_table_by_index(
				index		=> $index,
				oids		=> $params{'oids'},
			);

	return wantarray ? @output : \@output;
}

=head2 get_named_table_by_name

Depending upon L<get_index_by_name> and L<get_named_table_by_index>, this method will
use both to retreive index from a name and retreive the SNMP table for on instance.

To get  network interfaces on a machine and their status by index:

	$s->get_table_by_name( 
    			name => 'eth0',
			oid_names => 'ifDescr',
			oids	=> { 
					name => 'ifDescr', 
					status => 'ifOperStatus' 
					adminstatus => 'ifAdminStatus' 
					},
		);

Would return something like the following:

	[
        {
            name   => 'eth1'
            status => 'up',
            adminstatus => 'down',
        },
	];

If called in array context, returns an array. If called in scalar context, 
returns an array reference.

=cut

sub get_named_table_by_name {
	my $self	= shift;
	my %params = validate( @_, {
				name		=> 1, 
				oid_names	=> 1,
				oids		=> 1, 
			},
		);

	my $index = $self->get_index_by_name(
			name		=> $params{'name'},
			oid_names	=> $params{'oid_names'},
		);

	my @output = $self->get_named_table_by_index(
			index		=> $index,
			oids		=> $params{'oids'},
		);

	return wantarray ? @output : \@output;
}

=head2 get_index_by_foreign_index

Use L<get_indexed_table> to search instance of a SNMP table with his name.

Regulars expressions can be used by adding 'regexp' boolean parameter.

This following example:

	$self->get_index_by_foreign_index( 
				name => 'eth0', 
				oid_names => 'ifDescr', 
			);

Would return a ARRAY like the following:

	[ 1 ]
	

=cut

sub get_index_by_foreign_index {
	my $self	= shift;
	my %params = validate( @_, {
				index		=> 1, 
				oid_findexes	=> 1, 
				oid_table	=> 0, 
			},
		);

	my @oids;
	my @index;

	my $oid_table = $params{'oid_table'};
	if ( not defined( $oid_table ) ) {
		$oid_table = get_parent_oid( $params{'oid_findexes'} );
	}

	if ( defined( $oid_table ) ) {

		push @oids, $params{'oid_findexes'};

		my $indexed_table = $self->get_indexed_table(
					base		=> $oid_table,
					oids		=> \@oids,
					noindexes	=> 0,
				);

		foreach my $line ( sort { $a <=> $b } keys %$indexed_table ) {
			my $oid_foreign_index = $$indexed_table{$line}{ $params{'oid_findexes'} };

			# Equality matching
			if ( $oid_foreign_index eq $params{'index'} ) {
				push @index, $line;
			}
		}
	}
	else {
		$self->nagios_die(
				" Perhaps ". $params{'oid_findexes'} 
				." isn't an OID of a valid SNMP table.",
			);
	}

	if ( scalar( @index ) eq 0 ) {
		my $output = "No such instance for "
					. $params{'oid_findexes'}; #FIXME
		if ( $params{'oid_findexes'} !~ /\.\d+/ ) {
			$output .= " (". &SNMP::translateObj($params{'oid_findexes'}) .") ";
		}
		$output .= "with index equal to '". $params{'index'} ."'";
		$self->nagios_die( $output );
	}

	return wantarray ? @index : \@index;
}

=head1 PRIVATE FUNCTIONS

=head2 check_for_errors

=cut

sub check_for_errors {
	my $self	= shift;
	my %params	= validate( @_, {
				result	=> 0,
				oid	=> 1,
			},
	 	);

	my $output	= undef;

	if ( $self->session->{ErrorStr} ) {
		$output = "Could not retreive "
				. $params{'oid'}
				." : ". $self->session->{ErrorStr};
	} 
	else {
		if ( defined( $params{'result'} ) ) {
			if ( $params{'result'} eq 'NOSUCHINSTANCE' ) {
				$output	= "No such instance for";
			}
			elsif ( $params{'result'} eq 'NOSUCHOBJECT' ) {
				$output	= "No such object at";
			}
			if ( $params{'result'} =~ /NOSUCH/ ) {
				$output .= " ". $params{'oid'};
				if ( $params{'oid'} !~ /\.\d+/ ) {
					$output .= " ("
						. &SNMP::translateObj($params{'oid'})
						.")";
				}
			}
		}
	}

	if ( defined($output) ) {
		$self->nagios_die( $output );
	}
}

=head2 get_indexes_of

Get indexes OID name from provided OID, according to MIB informations.

Return undefined if no indexes can be found or if OID has no access or no 
parent defined.
Return an array in an array context and the first element of the array in a
scalar context.

Examples:

This following code

	print get_indexes_of( 'ifEntry' );

Would return this string:

	ifIndex

=cut

sub get_indexes_of {
	my $oid		= shift;

	my $access			= $SNMP::MIB{ $oid }{'access'};
	if ( defined($access) ) {

		my $parent_hashref	= $SNMP::MIB{ $oid }{'parent'};

		if ( defined($parent_hashref) ) {

			my $indexes_arrayref = $$parent_hashref{'indexes'};

			if ( defined($indexes_arrayref) ) {

				if ( @{$indexes_arrayref} > 1 ) {
					# Return array in an array context and an array ref in a
					# scalar context
					return wantarray ? @{$indexes_arrayref} 
									: $$indexes_arrayref;
				}
				else {
					# Return the uniq element of the array
					return $$indexes_arrayref[0];
				}
			}
			# no indexes
			else {
				return undef;
			}
		}
		# no parent
		else {
			return undef;
		}
	}
	# noAccess
	else {
		return undef;
	}
}

sub get_short_units_of {
	my $oid		= shift;

	my $unit	= get_units_of( $oid );
	
	switch($unit) {
		case /KBytes/i	{
			$unit	= "KB";
		}
	}
	
	return $unit;
}

sub get_units_of { 
	my $oid		= shift;

	my $unit 	= $SNMP::MIB{ $oid }{'units'};

	if ( defined($unit) ) {
		return $unit;
	}
	else {
		return undef;
	}
}

sub get_type_of {
	my $oid		= shift;

	my $type 	= $SNMP::MIB{ $oid }{'type'};

	if ( defined($type) ) {
		return $type;
	}
	else {
		return undef;
	}
}

sub get_parent_oid {
	my $oid		= shift;
	my $oid_table;

	#
	# Get HASH ref to parent OID
	#
	#  Example : 
	#   ifEntry
	#     \_ ifDescr
	#
	#  ifEntry is the parent OID of ifDescr
	#
	my $oid_parent = $SNMP::MIB{ $oid }{'parent'};

	#
	# Get HASH ref to table OID using the label of precedent OID
	#
	#  Example : 
	#   ifTable
	#     \_ ifEntry
	#          \_ ifDescr
	#
	#  ifTable is the parent OID of ifEntry and the table OID
	#  ifEntry is the parent OID of ifDescr
	#
	if ( defined( $oid_parent ) ) {
		$oid_table = $SNMP::MIB{ $$oid_parent{'label'} }{'parent'};
		return $$oid_table{'label'};
	}

	return undef;
}

sub get_oids_list {
	my $self	= shift; 
	my %params	= validate( @_, {
				oid		=> 1,
				index	=>	0,
			},
	 	);

	my @results	= ();
	my $vars	= undef;

	# build varlist, the fun VarList way
	if ( defined( $params{'index'} ) ) {

		my @map					= ();

		foreach my $oid ( @{$params{'oid'}} ) {
			my @varbind = ( $oid );

			my $indexes = get_indexes_of( $oid );
			if ( defined( $indexes ) ) {
				push @varbind, $params{'index'};
			}
			else {
				push @varbind, 0;
			}

			push @map, \@varbind;
		}

		$vars = SNMP::VarList->new( 
				@map,
			);
	}
	else {
		my @map					= ();

		foreach my $oid ( @{$params{'oid'}} ) {
			my @varbind = ( $oid );

			my $indexes = get_indexes_of( $oid );
			if ( not defined( $indexes ) ) {
				push @varbind, 0;
			}

			push @map, \@varbind;
		}

		$vars = SNMP::VarList->new( 
				@map,
		);
	}
		
	if ( defined($self->opts->v1) ) {
		@results = $self->session->get( $vars );
	}
	else {
		@results = $self->session->getbulk(
				0,
				1, 
				$vars,
			); #FIXME
	}

	foreach my $oid ( @$vars ) {
		$self->check_for_errors( 
				result	=>	$oid->val,
				oid	=>	$oid->name,
			);
	}

	return wantarray ? @results : \@results;
}

=head1 AUTHOR

Raphael 'SurcouF' Bordet, C<< <surcouf at debianfr.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-nagios-plugin-netsnmp at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Monitoring-Plugin-SNMP>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Monitoring::Plugin::SNMP::Requests


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Monitoring-Plugin-SNMP>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Monitoring-Plugin-SNMP>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Monitoring-Plugin-SNMP>

=item * Search CPAN

L<http://search.cpan.org/dist/Monitoring-Plugin-SNMP>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2008 Raphael 'SurcouF' Bordet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Monitoring::Plugin::SNMP::Requests
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
