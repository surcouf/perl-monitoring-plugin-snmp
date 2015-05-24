#
# Monitoring::Plugin::SNMP - OO perl module providing standardised argument 
#   processing and some functions for nagios SNMP plugins
#
package Monitoring::Plugin::SNMP;

use strict;
use warnings;

use Switch;

use Params::Validate			qw/ validate /;

use Monitoring::Plugin;
use Monitoring::Plugin::Functions	qw/ @STATUS_CODES /;
use Monitoring::Plugin::SNMP::Getopt;
use Monitoring::Plugin::SNMP::Requests;

use SNMP 5.0205;

=head1 NAME

Monitoring::Plugin::SNMP - OO perl module providing standardised argument 
processing and some functions for nagios SNMP plugins

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Monitoring::Plugin::SNMP;

    my $foo = Monitoring::Plugin::SNMP->new();
    ...

=head1 EXPORT

A list of functions that can be exported.

=cut

use Exporter;
our @ISA	= qw/ Exporter Monitoring::Plugin /;
our @EXPORT	= ( @STATUS_CODES );
our @EXPORT_OK	= qw/ %ERRORS /;


=head1 FUNCTIONS

=head2 new

Constructor

=cut

sub new {
	my $proto	= shift;
	my $class	= ref( $proto ) || $proto;
	my %args	= @_;

	my $mibs	= undef;

	if ( defined( $args{'mibs'} ) ) {
		$mibs = $args{'mibs'};
		delete $args{'mibs'};
	}

	# Fill automaticaly usage information from options specifications
	if ( not defined($args{'usage'}) ) {
		$args{'usage'} = fill_usage(
					plugin	=>	$args{'plugin'},
				);
	}
	elsif ( $args{'usage'} !~ /^Usage.*/ ) {
		$args{'usage'} = fill_usage(
					plugin	=>	$args{'plugin'},
					usage	=>	$args{'usage'},
				);
	}

	my $self = $class->SUPER::new(%args);

	# ref to SNMP::Session object.
	$self->{'_session'} = undef;

	# array ref to additionals MIB list
	$self->{'_mibs'}	= $mibs;

	# add SNMP related options
	@{$self->opts->{_args}} = add_snmp_options(
			@{$self->opts->{_args}},
		);

	bless ($self, $class);

	return $self;
}

=head2 connect

Connect to SNMP agent and create a SNMP::Session object ref for Monitoring::Plugin::SNMP object.

=cut

sub connect {
	my $self 	= shift;
	my $errors 	= undef;
   	my %params = validate( @_, {
				UseLongNames	=>	0,
				UseSprintValue	=>	0,
				UseEnums		=>	{ default => 1 },
				UseNumeric		=>	0,
			},
		);

	#
	# Check if options and arguments to be passed to Net::SNMP->session are corrects.
	#  Example: seclevel can't be used with community.
	#
	my $args = $self->check_snmp_options();

	#
	# Enable SNMP Perl module debug mode
	# 
	if ( defined $self->opts->debug ) {
		$SNMP::debugging = 1;
	}

	#
	# Add additionals MIB
	#
	$SNMP::save_descriptions = 1;
	&SNMP::initMib;

	if ( defined $self->opts->mibs ) {
		# MIB list must be a comma separated list of alphanumerical 
		#  (including hyphens) names.
		if ( $self->opts->mibs =~ /[\w,-]+/ ) {
			my @mibs = split(/,/, $self->opts->mibs );
			push @{$self->{'_mibs'}}, @mibs;
		}
	}

	foreach my $mib ( @{$self->{'_mibs'}} ) {
		&SNMP::loadModules("$mib");
	}
	
	#
	# Check for gobal timeout if SNMP screw up
	#
	$SIG{'ALRM'} = sub {
		$self->nagios_die( "General time-out (Alarm signal)" );
	};
	alarm( $self->opts->timeout );

	# 
	# Create Net::SNMP session and store returned object into Monitoring::Plugin object.
	#
	$self->{'_session'} = SNMP::Session->new( 
					%$args,
					%params,
				);
	
	if (not defined($self->session)) {
		$self->nagios_die( "Can't connect to device ! ($errors)" );
	}
}

=head1 PRIVATE FUNCTIONS

=head2 session

Return ref to SNMP::Session object.

=cut

sub session {
	my $self 	= shift;

	return $self->{'_session'};
}



=head1 AUTHOR

Raphael 'SurcouF' Bordet, C<< <surcouf at debianfr.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-nagios-plugin-netsnmp at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Monitoring-Plugin-SNMP>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Monitoring::Plugin::SNMP


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

1; # End of Monitoring::Plugin::SNMP
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
