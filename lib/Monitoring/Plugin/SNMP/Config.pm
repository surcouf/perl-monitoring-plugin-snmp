#
# Monitoring::Plugin::SNMP::Config - OO perl module providing standardised argument 
#   processing and some functions for nagios SNMP plugins
#
package Monitoring::Plugin::SNMP::Config;

use strict;
use warnings;

use Switch;

use Params::Validate		qw/ validate /;

=head1 NAME

Monitoring::Plugin::SNMP::Config - OO perl module providing standardised argument 
processing and some functions for nagios SNMP plugins

=head1 VERSION

Version 0.01

=cut

our $VERSION = $Monitoring::Plugin::SNMP::VERSION;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Monitoring::Plugin::SNMP::Config;

    my $foo = Monitoring::Plugin::SNMP::Config->new();
    ...

=head1 EXPORT

A list of functions that can be exported.

=cut

use Exporter;
our @ISA = qw/ Exporter /;
our @EXPORT	= qw/ 
	check_configuration_files
		/;

our @EXPORT_OK	= qw/ /;

=head1 DATA

=head2 SNMP related default configuration files

=cut

my @FILENAMES = (
		$ENV{'HOME'} .'/.snmp/snmp.conf',
		'/usr/local/etc/snmp/snmp.local.conf',
		'/usr/local/etc/snmp/snmp.conf',
		'/etc/snmp/snmp.local.conf',
		'/etc/snmp/snmp.conf',
	);

my %snmpOptions = (
		'defPassPhrase'		=>	'AuthPass',	
		'defAuthPassphrase'	=>	'AuthPass',	
		'defAuthType'		=>	'AuthProto',	
		'defCommunity'		=>	'Community',	
		'defPrivPassphrase'	=>	'PrivPass',	
		'defPrivType'		=>	'PrivProto',	
		'defaultPort'		=>	'RemotePort',	
		'defSecurityLevel'	=>	'SecLevel',	
		'defSecurityName'	=>	'SecName',	
		'defVersion'		=>	'Version',	
		'defContext'		=>	'Context',
		'printNumericEnums'	=>	'UseEnums',
		'printNumericOids'	=>	'UseNumeric',
	);

=head1 FUNCTIONS

=head2 get_configuration()

=cut

sub check_configuration_files {
	
	my $filename	= _get_snmpconf();

	return _get_configuration( $filename );
}

=head1 PRIVATE FUNCTIONS

=head2 _get_snmpconf()

=cut

sub _get_snmpconf {
	my $filename	= undef;

	foreach my $file ( @FILENAMES ) {
		if ( -r $file and -s $file ) {
			$filename = $file;
			last;
		}
	}

	return $filename;
}

=head2 _get_configuration()

=cut

sub _get_configuration {
	my $filename	= shift;

	my %options	= ();

	if ( open( SNMPCONF, "< $filename " ) ) {

		while ( my $line = <SNMPCONF> ) {
			chomp($line);

			foreach my $name ( keys %snmpOptions ) {

				if ( $line =~ s/^$name[[:space:]]+(\w+)$/$1/ ) { 
					my $option = $1;

					switch($name) {
						case /defaultPort/ {
							if ( $option !~ /\d+/ ) {
								$option = undef;
							}
						}
						case /defVersion/ {
							switch($option) {
								case /(1|2|3)/ {}
								case /2c/ { $option = '2'; }
								default	{ $option = undef; }
							}
						}
						case /def(Auth|Priv)Type/ { 
							$option = uc($option); 
							switch($option) {
								case /(MD5|SHA)/ {}
								case /(DES|AES)/ {}
								default	{ $option = undef; }
							}
						}
						case /defSecurityLevel/ {
							switch($option) {
								case /(noAuthNoPriv|authNoPriv|authPriv)/ {}
								default	{ $option = undef; }
							}
						}
						case /defPassPhrase/ {
							$options{'AuthPass'} = $option;
							$options{'PrivPass'} = $option;
						}
					}

					if ( defined($option) ) {
						$options{ $snmpOptions{$name} } = $option; 
					}
				}
			}

		}

		close SNMPCONF;
	}

	return wantarray ? %options : \%options;
}


=head1 AUTHOR

Raphael 'SurcouF' Bordet, C<< <surcouf at debianfr.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-nagios-plugin-netsnmp at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Monitoring-Plugin-SNMP>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Monitoring::Plugin::SNMP::Config


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

1; # End of Monitoring::Plugin::SNMP::Config
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
