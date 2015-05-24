#
# Monitoring::Plugin::SNMP::Getopt - OO perl module providing standardised argument 
#   processing and some functions for nagios SNMP plugins
#
package Monitoring::Plugin::SNMP::Getopt;

use strict;
use warnings;

use Switch;

use Params::Validate		qw/ validate /;

use Monitoring::Plugin::SNMP::Config;

=head1 NAME

Monitoring::Plugin::SNMP::Getopt - OO perl module providing standardised argument 
processing and some functions for nagios SNMP plugins

=head1 VERSION

Version 0.01

=cut

our $VERSION = $Monitoring::Plugin::SNMP::VERSION;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Monitoring::Plugin::SNMP::Getopt;

    my $foo = Monitoring::Plugin::SNMP::Getopt->new();
    ...

=head1 EXPORT

A list of functions that can be exported.

=cut

use Exporter;
our @ISA	= qw/ Exporter /;
our @EXPORT	= qw/ 
			add_snmp_options
			add_thresholds_opts
			add_perfdata_opts
			add_name_opts
			check_snmp_options
			fill_usage
		/;

our @EXPORT_OK	= qw/ /;

=head1 DATA

=head2 SNMP related default options

A list of options that are already defined to be used in Monitoring plugins.

=cut

my @snmpOpts = (
	{
	# Hostname 
		spec		=>	'hostname|H=s',
		help		=>	"-H, --hostname=STRING\n"
					."    Hostname where Net-SNMP agent is hosted.",
		required	=>	1,
	}, {
	# SNMP port number
		spec		=>	'port|p=i',
		help		=>	"-P, --port=INTEGER\n"
					."   SNMP port (Default: 161).",
		required	=>	0,
		default		=>	161,
	}, {
	# SNMP version
		spec		=>	'v1|1',
		help		=>	"-1, --v1 \n   Enable SNMPv1 protocol version.",
		required	=>	0,
	}, {
		spec		=>	'v2c|2',
		help		=>	"-2, --v2c \n   Enable SNMPv2c protocol version (default).",
		required	=>	0,
	}, {
		spec		=>	'v3|3',
		help		=>	"-3, --v3 \n   Enable SNMPv3 protocol version.",
		required	=>	0,
	}, {
	# Community string
		spec		=>	'community|C=s',
		help		=>	"-C, --community=STRING\n"
					."   Community name for the host's SNMP agent (SNMPv1 or v2c).",
		required	=>	0,
	}, {
	# SNMPv3 seclevel
		spec		=>	'seclevel|l=s',
		help		=>	"-l, --seclevel={noAuthNoPriv,authNoPriv,authPriv}\n"
					."   Security Level for SNMPv3 authentication",
		required	=>	0,
	}, {
	# SNMPv3 secname
		spec		=>	'secname|u=s',
		help		=>	"-u, --secname=STRING\n"
					."   Login for SNMPv3 authentication",
		required	=>	0,
	}, {
	# SNMPv3 auth protocol
		spec		=>	'authproto|a=s',
		help		=>	"-a, --authpasswd={md5|sha}\n"
					."   Auth protocol for SNMPv3 authentication",
		required	=>	0,
	}, {
	# SNMPv3 auth password
		spec		=>	'authpasswd|A=s',
		help		=>	"-A, --authpasswd=STRING\n"
					."   Auth password for SNMPv3 authentication",
		required	=>	0,
	}, {
	# SNMPv3 priv protocol
		spec		=>	'privproto|x=s',
		help		=>	"-x, --privproto={des|aes}\n"
					."   Priv protocol for SNMPv3 encryption",
		required	=>	0,
	}, {
	# SNMPv3 priv password
		spec		=>	'privpasswd|X=s',
		help		=>	"-X, --privpass=STRING\n"
					."   Priv password for SNMPv3 encryption",
		required	=>	0,
	}, {
	# SNMPv3 context name 
		spec		=>	'context|N=s',
		help		=>	"-N, --context=STRING\n"
					."   SNMPv3 context name",
		required	=>	0,
	}, {
	# Net-SNMP MIBS list
		spec		=>	'mibs|m=s',
		help		=>	"-m, --mibs=STRING\n"
					."   Additional MIB list to be loaded",
		required	=>	0,
	}, {
	# Debug mode
		spec		=>	'debug|d',
		help		=>	"-d, --debug\n"
					."   Enable debug mode",
		required	=>	0,
	},
);

=head1 FUNCTIONS

=head2 add_snmp_options

=cut

sub add_snmp_options {
	my $self	= shift;
	my @options	= shift;

	foreach my $option ( @snmpOpts ) {
		push @options, $option ;
	}

	return wantarray ? @options : \@options;
}

=head2 check_snmp_options

Check default options related to SNMP and return hash ref.

=cut

sub check_snmp_options {
	my $self 		= shift;

	my %snmpOpts		= check_configuration_files();

	$snmpOpts{'DestHost'} 	= $self->opts->hostname;
	$snmpOpts{'Timeout'}	= $self->opts->timeout * 10e6;	# SNMP timeout unit 
								# are exprimed in
								# microseconds.
	
	if ( not defined($snmpOpts{'RemotePort'}) ) {
		$snmpOpts{'RemotePort'}	= $self->opts->port;
	}

	if ( defined( $self->opts->v1 ) ) {
		$snmpOpts{'Version'}	= "1"; 
	}
	elsif ( defined( $self->opts->v2c ) ) {
		$snmpOpts{'Version'}	= "2"; 
	}
	elsif ( defined( $self->opts->v3 ) ) {
		$snmpOpts{'Version'}	= "3"; 
	}
	elsif ( not defined($snmpOpts{'Version'}) ) {
		$snmpOpts{'Version'}	= "2"; 
	}

	switch($snmpOpts{'Version'}) {
		#
		# SNMPv1 or SNMPv2
		#
		case /(1|2)/ {
			if ( not defined($snmpOpts{'Community'}) ) {
				if ( defined($self->opts->community) ) {
					$snmpOpts{'Community'}	= $self->opts->community;
				}
				else {
					$self->nagios_die(
							"Missing SNMP community"
						);
				}
			} 
		}
		#
		# SNMPv3
		#
		case /3/ {
			if ( not defined($snmpOpts{'SecLevel'}) ) {

				$snmpOpts{'SecLevel'} = _check_seclevel(
						$self,
						$self->opts->seclevel,
					);

				if ( not defined($snmpOpts{'SecLevel'}) ) {

					$self->nagios_die(
							"Missing seclevel with SNMPv3."
						);
				}
			}

			if ( defined( _check_seclevel( $self, $snmpOpts{'SecLevel'} ) ) ) {
						
				switch(lc($snmpOpts{'SecLevel'})) {
					case 'authpriv'	{
						if ( not defined($snmpOpts{'PrivProto'}) ) {
							$snmpOpts{'PrivProto'} = uc($self->opts->privproto);
						}
						$snmpOpts{'PrivProto'} = _check_privproto( 
								$self,
								$snmpOpts{'PrivProto'},
							);
						
						if ( not defined($snmpOpts{'PrivPass'}) ) {
							if ( defined($self->opts->privpasswd) ) {
								$snmpOpts{'PrivPass'} = $self->opts->privpasswd;
							}
							else {
								$self->nagios_die(
										"Missing privpasswd with selected seclevel ("
										.$self->opts->seclevel.")",
									);
							}
						}

						next;
					}
					case 'authnopriv' {
						if ( not defined($snmpOpts{'AuthProto'}) ) {
							$snmpOpts{'AuthProto'} = uc($self->opts->authproto);
						}
						$snmpOpts{'AuthProto'} = _check_authproto( 
								$self,
								$snmpOpts{'AuthProto'},
							);
						
						if ( not defined($snmpOpts{'AuthPass'}) ) {
							if ( defined($self->opts->authpasswd) ) {
								$snmpOpts{'AuthPass'} = $self->opts->authpasswd;
							}
							else {
								$self->nagios_die(
										"Missing authpasswd with selected seclevel ("
										.$self->opts->seclevel.")",
									);
							}
						}

						next;
					}
					case 'noauthnopriv' { 
						last;
					}
					else {
						if ( not defined($snmpOpts{'SecName'}) ) {

							if ( defined($self->opts->secname) ) {
								$snmpOpts{'SecName'} = $self->opts->secname;
							}
							else {
								$self->nagios_die(
										"Missing secname with SNMPv3"
									);
							}
						}
					}
				}
			}
			else {
				$self->nagios_die(
						"Invalid seclevel (". $snmpOpts{'SecLevel'} .")."
					);
			}

			if ( defined($self->opts->context) ) {
				$snmpOpts{'Context'}	= $self->opts->context;
			}
		}
	}

	return wantarray ? %snmpOpts : \%snmpOpts;
}

=head2  add_perfdata_opts()

Add -f, --perfdata option to Monitoring::Plugin::SNMP::Getopt objet.

=cut

sub add_perfdata_opts {
	my $self 	= shift;
	
	$self->add_arg(
			spec		=>	'perfdata|f',
			help		=>	"-f, --perfdata\n   "
						. "Enable performance data display.",
			required	=>	0,
		);
}

=head2 add_thresholds_opts( [required => 0] )

Add following thresholds option to Monitoring::Plugin::SNMP::Getopt objet : 
	* -w, --warning=INTEGER:INTEGER,
	* -c, --critical=INTEGER:INTEGER.

=cut

sub add_thresholds_opts {
	my $self 	= shift;
   	my %params 	= validate( @_, {
				required	=> {
						default => 0,
					},
			},
		);
	
	$self->add_arg(
			spec 		=>	'warning|w=s',
 	      		help 		=>	"-w, --warning=INTEGER:INTEGER.\n   See "
        			        	. "http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT "
        	        			. "for the threshold format. ",
			required	=>	$params{'required'},
		);
	
	$self->add_arg(
			spec 		=> 	'critical|c=s',
			help 		=> 	"-c, --critical=INTEGER:INTEGER.\n   See "
						. "http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT "
						. "for the threshold format. ",
			required	=>	$params{'required'},
		);
};

=head2 add_name_opts( description => "Some descr", [required => 0] )

Add naming pattern options to Monitoring::Plugin::SNMP::Getopt objet : 
	* -n, --name=STRING,
	* -r, --regexp.

=cut

sub add_name_opts {
	my $self 	= shift;
   	my %params	= validate( @_, {
				description	=> 1,
				required	=> {
						default => 0,
					},
			},
		);
	
	$self->add_arg(
			spec		=>	'name|n=s',
			help		=>	"-n, --name=STRING\n   "
						. $params{'description'},
			required	=>	$params{'required'},
		);

	$self->add_arg(
			spec		=>	'regexp|r',
			help		=>	"-r, --regexp\n   "
						. "Enable regular expression pattern matching instead of equality matching.",
			required	=>	0,
		);
};

=head1 PRIVATE FUNCTIONS

=head1 fill_usage

=cut 

sub fill_usage {
	my %params = validate( @_, {
			plugin	=> 1,
			usage	=> 0,
		},
 	);
	my $usage 	= "Usage: %s";

	foreach my $options ( @snmpOpts ) {
		my ($long,$short) = split(/\|/, $$options{'spec'});

		my $type = undef;
		($short,$type) = split("=", $short);

		my $spec = "-". $short;

		if ( defined($type) ) {
			$spec .= " <". $long .">";
		}

		if ( defined($$options{'required'}) ) {
			$usage .= " [". $spec ."]";
		}
		else {
			$usage .= " ". $spec;
		}
	}
	if ( defined( $params{'usage'} ) ) {
		$usage .= " ". $params{'usage'} ."\n\n";
	}
	$usage .= " \n\n"
		."Use option --help for more information\n"
	 	.$params{'plugin'} 
		." comes with ABSOLUTELY NO WARRANTY\n\n";

	return $usage;
}

=head2 _check_seclevel

Check if provided Security Level is defined and valid

=cut

sub _check_seclevel {
	my $self	= shift;
	my $level	= shift;

	my $seclevel	= undef;

	if ( defined($level) ) {

		switch( lc($level) ) {
			case 'noauthnopriv' { 
				$seclevel	= 'noAuthNoPriv';
			}
			case 'authnopriv' {
				$seclevel	= 'authNoPriv';
			}
			case 'authpriv'	{
				$seclevel	= 'authPriv';
			}
			default {
				$self->nagios_die("Invalid seclevel ($level)" );
			}
		}
	}
	else {
		$self->nagios_die("Missing seclevel option." );
	}

	return $seclevel;
}

=head2 _check_authproto

Check if provided Authentication Protocol is defined and valid

=cut

sub _check_authproto {
	my $self	= shift;
	my $proto	= shift;

	my $authproto	= undef;

	if ( defined( uc($proto) ) ) {
		
		switch($proto) {
			case /(MD5|SHA)/ {
				$authproto	= $proto;
			}
			default {
				$self->nagios_die("Invalid authproto ($proto)" );
			}
		}
	}
	else {
		$self->nagios_die("Missing authproto option." );
	}

	return $authproto;
}

=head2 _check_privproto

Check if provided Privacy Protocol is defined and valid

=cut

sub _check_privproto {
	my $self	= shift;
	my $proto	= shift;

	my $privproto	= undef;

	if ( defined( uc($proto) ) ) {
		
		switch($proto) {
			case /(DES|AES)/ {
				$privproto	= $proto;
			}
			default {
				$self->nagios_die("Invalid privproto ($proto)" );
			}
		}
	}
	else {
		$self->nagios_die("Missing privproto option." );
	}

	return $privproto;
}

=head1 AUTHOR

Raphael 'SurcouF' Bordet, C<< <surcouf at debianfr.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-nagios-plugin-netsnmp at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Monitoring-Plugin-SNMP>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Monitoring::Plugin::SNMP::Getopt


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

1; # End of Monitoring::Plugin::SNMP::Getopt
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
