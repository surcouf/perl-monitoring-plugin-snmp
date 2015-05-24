#!/usr/bin/perl
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#==========================================================================
# Summary
#==========================================================================
# This plugin retrieve LM-SENSORS usage for temperature, fan, voltage and misc
# sensors throught SNMP protocol, using LM-SENSORS-MIB.
# 
# Copyright (C) 2011 Raphaël 'SurcouF' Bordet <surcouf@debianfr.net>
# 
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
# Version 0.03 (2008/03/17):
# - Ported to Monitoring::Plugin::SNMP
# Version 0.02 (2006/10/04):
# - Add perfdata support
# Version 0.01 (2006/01/13):
# - First version
# Author: Raphaël 'SurcouF' Bordet
#==========================================================================

#==========================================================================
# Version
#==========================================================================
my $VERSION = '0.3';

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
my $help;
my $version;
my $verbose 		= 0;

my @oidslist		= ();

my $o_regexp		= undef;
my $o_eregexp 		= undef;
my $o_exclude		= undef;

my $system		= undef;
my $configure_opts	= undef;

my $result		= undef;

my $temperature		= undef;

my $output		= undef;

my $status 		= UNKNOWN;


# LM-SENSORS-MIB::lmSensorsTable
my %lmSensorsDevice 	= (
		temp	=>	"lmTempSensorsDevice",
		fan	=>	"lmFanSensorsDevice",
		volt	=>	"lmVoltSensorsDevice",
		misc	=>	"lmMiscSensorsDevice",
	);

my %lmSensorsValue 	= (
		temp	=>	"lmTempSensorsValue",
		fan	=>	"lmFanSensorsValue",
		volt	=>	"lmVoltSensorsValue",
		misc	=>	"lmMiscSensorsValue",
	);

my %lmSensorsUnit	= (
		temp	=>	"degC",
		fan	=>	"RPM",
		volt	=>	"mV",
		misc	=>	"",
	);

my %oids_named_list;

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $plugin = Monitoring::Plugin::SNMP->new (
		shortname	=>	'UCD-SNMP lmSensors',
		version		=>	$VERSION,
		blurb		=>	'This plugin check LM-SENSORS from a Net-SNMP agent.',
		plugin		=>	$progname,
		extra		=>	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
					."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
	);

# Add warning and critical threshold options
$plugin->add_thresholds_opts();

# Add perdata option
$plugin->add_perfdata_opts();

# Add name and regexp options
$plugin->add_name_opts(
  		description	=>	"Sensor Name to check",
	);

# 
# type option definition
#
$plugin->add_arg(
		spec		=>	'type|T=s',
   		help		=>	"-T, --type={temp|fan|volt|misc}\n"
    					."   Sensor type to check (default: temp)",
		required	=>	1,
		default		=>	'temp',
	);

$plugin->getopts;

switch( $plugin->opts->type ) { 
	case "temp" { }
	case "fan" { }
	case "volt" { }
	case "misc" { }
	else {
		$plugin->nagios_exit(
			$status,
			"Wrong sensors type ! Please select one of them : \n"
			." - 'temp',\n"
			." - 'fan',\n"
			." - 'volt',\n"
			." - 'misc'.",
			);
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
# Get system description and agent configure options
#
$system = $plugin->get_request( oid => 'sysDescr' ); 
$configure_opts = $plugin->get_request( oid => 'versionConfigureOptions' );

if ( defined( $plugin->opts->name ) ) {
	#
	# Get OID index by name
	#
	$oids_named_list{'name'}	= $lmSensorsDevice{ $plugin->opts->type };
	$oids_named_list{'value'}	= $lmSensorsValue{ $plugin->opts->type };

	$result = $plugin->get_named_table_by_name( 
			name		=> $plugin->opts->name,
			oid_names	=> $lmSensorsDevice{ $plugin->opts->type },
			oids		=> \%oids_named_list, 
		);

	foreach my $sensor ( @{$result}) {

		foreach my $oid ( keys %oids_named_list ) {

			if ( $oid eq 'name' ) {
				next;
			}

			my $uom 	= undef;
			my $value 	= $$sensor{ $oid };

			my $name	= $$sensor{'name'};
			$name 		=~ s/ /_/g;

			if ( $plugin->opts->type eq 'temp' ) {
				#
				# If operating system is Solaris or SunOS, temperature value compute is 
				# different.
				# Since Solaris 10, a new SNMP agent was provided, SMA, a vendor version of
				# the Net-SNMP agent.
				#
				if ( $system =~ /SunOS/ and 
					$configure_opts !~ /\/sma\// ) {

					$temperature = ( $value - 28005 ) / 65536;
				}
				else {
					$temperature = $value / 1000;
				}
	
				$output = "'$name' = $temperature degC";	# chr(276)
				$status = $plugin->check_threshold(
							$temperature 
						);
	
				$plugin->add_message(
						$status,
						$output,
					);

				#
				# Add perfdata values if needed
				#
				if ( defined( $plugin->opts->perfdata ) ) {
					$plugin->add_perfdata(
							label		=>	$name,
							value		=>	$temperature,
							uom			=>	$lmSensorsUnit{ $plugin->opts->type },
							threshold	=>	$plugin->{'threshold'},
						);
				}
			}
			elsif ( $plugin->opts->type eq 'fan' ) {
				$plugin->nagios_exit(
						message		=> "Not implemented yet.",
						return_code	=> $status,
					);
			}
			elsif ( $plugin->opts->type eq 'volt' ) {
				$plugin->nagios_exit(
						message		=> "Not implemented yet.",
						return_code	=> $status,
					);
			}
			elsif ( $plugin->opts->type eq 'misc' ) {
				$plugin->nagios_exit(
						message		=> "Not implemented yet.",
						return_code	=> $status,
					);
			}
		}
	}
} 

#==========================================================================
# Exit with Monitoring codes
#==========================================================================

($status, $output) = $plugin->check_messages();

$plugin->nagios_exit(
		message		=> $output,
		return_code	=> $status,
	);

