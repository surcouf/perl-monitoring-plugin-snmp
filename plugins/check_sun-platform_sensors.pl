#!/usr/bin/perl
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#==========================================================================
# Summary
#==========================================================================
# This plugin retrieve SUN Platform usage for temperature, fan, 
# voltage, etc. sensors throught SNMP protocol, using ENTITY-MIB and 
# SUN-PLATFORM-MIB (needed).
# 
# Copyright (C) 2011 Raphaël 'SurcouF' Bordet <surcouf@debianfr.net>
# 
#==========================================================================
# License: GPLv2
#==========================================================================
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# GPL License: http://www.gnu.org/licenses/gpl.txt
#
#==========================================================================

#==========================================================================
# Changelog
#==========================================================================
# Version 0.01 (2011/02):
# - First version
# Author: Raphaël 'SurcouF' Bordet
#==========================================================================

#==========================================================================
# Version
#==========================================================================
my $VERSION = '0.01';

#==========================================================================
# Modules
#==========================================================================

use strict;
use Monitoring::Plugin::SNMP;
use File::Basename qw(basename);
use Switch;

use Data::Dumper;

#==========================================================================
# Options
#==========================================================================
my $progname		= basename($0);

my %oids_named_list	= ();

my $i_sensors		= undef;
my $entity			= undef;
my $sensor			= undef;
my $numeric			= undef;
my $unit			= undef;
my $value			= undef;
my $output			= undef;
my $status 			= UNKNOWN;


#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $plugin = Monitoring::Plugin::SNMP->new(
	shortname	=>	'SUN-PLATFORM sensors',
	version		=>	$VERSION,
	blurb		=>	'This plugin check sensors from a Sun SNMP Management Agent for '
				. 'SunFire and Netra platform.',
	plugin		=>	$progname,
	extra   	=>	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
				. "\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
	mibs		=>	[ 'ENTITY-MIB', 'SUN-PLATFORM-MIB' ]
	);

# Add warning and critical threshold options
$plugin->add_thresholds_opts();

# Add perdata option
$plugin->add_perfdata_opts();

# Add name and regexp options
$plugin->add_name_opts(
		description	=>	"Sensor physical entity name",
	);

$plugin->add_arg(
		spec	=>	'type|T=s',
		help	=>	qq{-t, --type=(fan|volt|temp)\n	Type of sensors},
	);

$plugin->getopts;

my %types = (
		'fan'	=> 'tachometer',
		'temp'	=> 'temperature',
		'volt'	=> 'voltage',
	);

my $type = undef;

if ( defined( $plugin->opts->type ) ) {
	
	$type = $types{ $plugin->opts->type };

	if ( not defined($type) ) {
		 $plugin->plugin_die( "Unknown type of sensor (". $plugin->opts->type .")" );
	}

}

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$plugin->connect();

# 
# Fill OID list for request
#
%oids_named_list = (
		# entity OID
		phyName		=>	'entPhysicalName',
		phyDescr	=>	'entPhysicalDescr',
		phyClass	=>	'entPhysicalClass',
		# Sun Platform specific OID
		admnState	=>	'sunPlatEquipmentAdministrativeState',
		operState	=>	'sunPlatEquipmentOperationalState',
		alrmStatus	=>	'sunPlatEquipmentAlarmStatus',
		unknStatus	=>	'sunPlatEquipmentUnknownStatus',
		# Sensors specific OID
		sensorClass	=>	'sunPlatSensorClass',
		sensorType	=>	'sunPlatSensorType',
		# Numeric Sensors specific OID
		value		=>	'sunPlatNumericSensorCurrent',
		unit		=>	'sunPlatNumericSensorBaseUnits',
		exponent	=>	'sunPlatNumericSensorExponent',
		rate		=>	'sunPlatNumericSensorRateUnits',
		accuracy	=>	'sunPlatNumericSensorAccuracy',
		thresholds	=>	'sunPlatNumericSensorEnabledThresholds', #FIXME
	);

my %get_args;

if ( defined( $plugin->opts->name ) ) {
	$get_args{'name'}		=	$plugin->opts->name;
	$get_args{'oid_names'}	=	'entPhysicalName';
}
else {
	$get_args{'name'}		=	'numeric';
	$get_args{'oid_names'}	=	'sunPlatSensorClass';
}

#
# Get OID index by name
#
my $i_sensors = $plugin->get_index_by_name( %get_args );

#
# Get named table by name
#
my $entities = $plugin->get_named_table_by_index( 
		index		=>	$i_sensors,
		oids		=>	\%oids_named_list, 
	);

foreach my $entity ( @$entities ) {

	if ( $$entity{'operState'} eq 'enabled' ) {

		if ( $$entity{'admnState'} eq 'unlocked' ) {

			switch( $$entity{'alrmStatus'} ) {
				case 'critical' 	{ $status = CRITICAL; }
				case 'major'		{ $status = CRITICAL; }
				case 'minor'		{ $status = WARNING; }
				case 'warning'		{ $status = WARNING; }
				case 'pending'		{ $status = DEPENDENT; }
				case 'indeterminate'{ $status = UNKNOWN; }
				case 'cleared'		{ $status = OK; }
			}

			if ( $$entity{'unknStatus'} eq 'true' ) {
				$status = UNKNOWN; 
			}

			if ( $$entity{'phyClass'} =~ /sensor/ ) { 

				if ( $$entity{'sensorClass'} eq 'numeric' ) {
					debug( 'Entity name', $$entity{'phyName'} );
					debug( 'Sensor type', $$entity{'sensorType'} );

					# Skip others sensor types if only one of them is requested
					#
					if ( defined( $type ) ) {
						if ( $$entity{'sensorType'} ne $type ) {
							next;
						}
					}

					# If not null, apply exponent to value
					# 
					if ( $$entity{'exponent'} != 0 ) {
						$value = $$entity{'value'}
								* ( 10 ** $$entity{'exponent'} );
					}
					else {
						$value = $$entity{'value'};
					}

					# If Unit Rate isn't unknown or other, add rate unit to unit string
					#
					switch ( $$entity{'unit'} ) {
						case 'unknown'	{ $unit = ""; }
						case 'other'	{ $unit = ""; }
						else		{ $unit = $$entity{'unit'}; }
					}

					if ( $unit ne "" ) {

						if ( $$entity{'rate'} ne 'none' ) {
							switch( $$entity{'rate'} ) {
								case 'perMicroSecond'	{ $unit .= "/µs"; }
								case 'perMilliSecond'	{ $unit .= "/ms"; }
								case 'perSecond'		{ $unit .= "/s"; }
								case 'perMinute'		{ $unit .= "/m"; }
								case 'perHour'			{ $unit .= "/h"; }
								case 'perDay'			{ $unit .= "/day"; }
								case 'perWeek'			{ $unit .= "/week"; }
								case 'perMonth'			{ $unit .= "/month"; }
								case 'perYear'			{ $unit .= "/year"; }
							}
						}

						if ( $$entity{'accuracy'} != 0 ) {
							# FIXME : cannot test !
							$unit = "%";
						}

					}
					
					$output = $$entity{'phyDescr'} 
							." ( ". $$entity{'phyName'} ." )"
							." = $value $unit \n";

					if (defined ( $plugin->opts->warning ) 
				   		and defined ( $plugin->opts->critical )	) {
						$status = $plugin->check_threshold(
								$value,
							);
					}

					$plugin->add_message( $status, $output );
	
					if ( defined( $plugin->opts->perfdata ) ) {
						my $label = $$entity{'phyName'} ;
						$label =~ s/.*:([A-Za-z_\/-]+)/$1/;
						$label =~ s/\//_/g;
						$label = lc( $label );
	
						$plugin->add_perfdata(
								label		=>	$label,
								value		=>	$value,
								uom		=>	$unit,
								threshold	=>	$plugin->{'threshold'},
							);
					}
				}
	
			}
			else {
				debug(	"Physical class of the entity named '"
							. $$entity{'phyName'} ."' isn't sensor "
							. "( ". $$entity{'phyClass'} ." ).",
					);
			}
		}
		elsif ( $$entity{'admnState'} eq 'shuttingDown' ) {
			debug(	"Physical entity named '"
						. $$entity{'phyName'}
						."' is shutting down according to administrative state",
				);
		}
		else {
			debug(	"Physical entity named '"
						. $$entity{'phyName'}
						."' is locked according to administrative state",
				);
		}
	}
	else {
		debug(	"Physical entity named '"
					. $$entity{'phyName'}
					."' is disabled according to operational state",
			);
	}
}

#==========================================================================
# Exit with Monitoring codes
#==========================================================================

($status, $output)	= $plugin->check_messages();

$plugin->plugin_exit(
		message		=> $output,
		return_code	=> $status,
	);

sub debug {
        my $variable    = shift;
        my $value       = shift;

        my $message     = undef;

        if ( defined( $plugin->opts->debug ) ) {
                $message = $variable;
                $message .= " = $value" if ( defined($value) );
                print STDERR "DEBUG: $message \n";
        }
}

