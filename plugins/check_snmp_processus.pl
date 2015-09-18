#!/usr/bin/perl
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check processus through an SNMP agent that implement  
#  HOST-RESOURCES-MIB.
#
# Copyright (C) 2011 Raphaël 'SurcouF' Bordet
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
# GPL Licence : http://www.gnu.org/licenses/gpl.txt
#
#====================================================================

#====================================================================
# Changelog
#====================================================================
# Version 0.01 (2011/02):
# - First implementation
# Author: Raphaël 'SurcouF' Bordet
#====================================================================

use strict;

use Monitoring::Plugin::SNMP;
use File::Basename qw(basename);
use Switch;

my $error		= undef;
my $output		= undef;
my $status		= undef;
my $table		= undef;
my $resultat	= undef;

#==========================================================================
# Options
#==========================================================================
my $progname = basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $plugin = Monitoring::Plugin::SNMP->new (
		shortname	=> 	'SNMP Processus',
		version		=> 	'0.01',
		blurb		=> 	'This plugin check processus stats and statistics through a Net-SNMP agent.',
		plugin		=> 	$progname,
		extra		=> 	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
					."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
	);

# Add warning and critical threshold options
$plugin->add_thresholds_opts();

# Add perdata option
$plugin->add_perfdata_opts();

# Add name and regexp options
$plugin->add_name_opts(
		description	=>	"Name of requested processus",
	);

$plugin->getopts;

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$plugin->connect(
		UseSprintValue  =>  1,
	);

# 
# Fill OID list for request
#
my %oids_named_list = (
		name			=>	'hrSWRunName',
		path			=>	'hrSWRunPath',
		params			=>	'hrSWRunParameters',
		type			=>	'hrSWRunType',
		status			=>	'hrSWRunStatus',
		cpu_usage		=>	'hrSWRunPerfCPU',
		memory_usage	=>	'hrSWRunPerfMem',
	);

my %uom_named_list = (
		cpu_usage		=>	'ms',
		memory_usage	=>	Monitoring::Plugin::SNMP::get_units_of( 
								$oids_named_list{'memory_usage'}
							),
	);

#
# SNMP request
#
$resultat = $plugin->get_named_table_by_name( 
		name		=> $plugin->opts->name,
		oid_names	=> $oids_named_list{'name'},
		oids		=> \%oids_named_list, 
	);

foreach my $result ( @{$resultat} ) {

	foreach my $oid_name ( keys %oids_named_list ) {

		my $value 	= $$result{ $oid_name };
		my $name	= $$result{'name'};
		$name		=~ s/"//g;

		switch ($oid_name) {
			#
			# Check for processus status
			#
			case /status/	{
				switch($value) {
#					case /runnable/		{
#						$plugin->add_message(
#								WARNING,
#								"$name is probably waiting for resource",
#							);
#					}
					case /notRunnable/	{
						$plugin->add_message(
								WARNING,
								"$name is loaded but waiting for event \n",
							);
					}
					case /invalid/		{
						$plugin->add_message(
								CRITICAL,
								"$name isn't loaded \n",
							);
					}
				}
			} 
			case /cpu_usage/{
					$value /= 10;	# hrSWRunPerfCPU is exprimed in centi-seconds
					next;
			}
			case /usage/	{	
				$name		.= "_$oid_name";

				my $state = $plugin->check_threshold(
						$value,
					);

				# hrSWRunPerfMem can be exprimed with units in same string
				$value	=~	s/ $uom_named_list{$oid_name}//;

				$plugin->add_message(
						$state,
						"$name = $value ". $uom_named_list{$oid_name} .",",
					);

				if ( defined( $plugin->opts->perfdata ) ) {
		
					$plugin->add_perfdata(
							label		=>	$name,
							value		=>	$value,
							uom			=>	$uom_named_list{$oid_name},
							threshold	=>	$plugin->{'thresholds'},
						);
				}
			}
			default			{	next; }
		}
	}
}

#==========================================================================
# Exit with Monitoring codes
#==========================================================================

($status, $output) = $plugin->check_messages();

$plugin->plugin_exit(
		message		=> $output,
		return_code	=> $status,
	);

