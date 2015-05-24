#! /usr/bin/perl -w
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check the value of a pattern matching in any log file 
# monitored by a {UCD|Net}-SNMP agent.
#
# Copyright (C) 2011 Raphael Bordet
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
# Version 0.1 (2009/05):
# - First implementation
# Author: Raphaël 'SurcouF' Bordet
#====================================================================

use strict;
use Switch;

use Monitoring::Plugin::SNMP;
use File::Basename qw(basename);


my $output		= undef;
my $status		= UNKNOWN;
my $resultat	= undef;

#==========================================================================
# Options
#==========================================================================
my $progname = basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $plugin = Monitoring::Plugin::SNMP->new (
	shortname	=> 'logmatch',
	version		=> '0.31',
	blurb		=> 'This plugin check matches of defined regexp in log files monitored by a Net-SNMP agent.',
	plugin		=> $progname,
	extra		=> 	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
				."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
);

# Add warning and critical threshold options
$plugin->add_thresholds_opts();

# Add perdata option
$plugin->add_perfdata_opts();

# Add name and regexp options
$plugin->add_name_opts(
  		description	=> "Name of requested file.",
	);

$plugin->getopts;

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
my %oids_named_list = (
		name			=>	'logMatchName',
		regexp			=>	'logMatchRegEx',
		filename		=>	'logMatchFilename',
		cycle			=>	'logMatchCycle',
		counter			=>	'logMatchCurrentCounter',
	);

#
# SNMP request
#
$resultat = $plugin->get_named_table_by_name( 
		name		=> $plugin->opts->name,
		oid_names	=> 'logMatchName',
		oids		=> \%oids_named_list, 
	);

foreach my $logmatch ( @$resultat ) {
	
	if ( not $$logmatch{'erreur'} ) {

		my $mesg = "Number of matches ('"
				. $$logmatch{'regexp'} ."') in "
				. $$logmatch{'filename'}  
				." (". $$logmatch{'counter'} .") ";

		my $state = OK;

		if ( defined( $plugin->opts->warning ) 
			and defined( $plugin->opts->critical ) ) {

			$state = $plugin->check_threshold(
						check		=> $$logmatch{'counter'},
					);

			switch( $state ) {
				case OK	{
							$mesg .= "is under threshold.";
						}
				case WARNING {
							$mesg .= "is larger than "
									. $plugin->opts->warning;
						}
				case CRITICAL {
							$mesg .= "is larger than "
									. $plugin->opts->critical;
					}
			}
		}

		$plugin->add_message(
				$state,
				$mesg,
			);

		if ( $plugin->opts->perfdata ) {
			$$logmatch{'name'} =~ s|.*/(.*)$|$1|g;
			$plugin->add_perfdata(
					label		=> $$logmatch{'name'},
					value		=> $$logmatch{'counter'},
					threshold	=> $plugin->{'threshold'},
				);
		}
	}
}	

($status,$output) = $plugin->check_messages();

$plugin->nagios_exit(
   		$status,
		$output,
	);

