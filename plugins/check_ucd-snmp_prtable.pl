#! /usr/bin/perl -w
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check the number of each processus monitored by a 
# {UCD|Net}-SNMP agent.
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
# Version 0.01 (2008/06):
# - First implementation
# Author: Raphaël 'SurcouF' Bordet
#====================================================================

use strict;
use Switch;

use Monitoring::Plugin::SNMP;
use File::Basename qw(basename);

my $uom			= "kB";
my $error		= undef;
my $output		= undef;
my $status		= UNKNOWN;
my $resultat		= undef;
my $warning		= undef;
my $critical		= undef;

#==========================================================================
# Options
#==========================================================================
my $progname 		= basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $ucdsnmp_prtable = Monitoring::Plugin::SNMP->new (
		shortname	=> 'UCD-SNMP proc table',
		version		=> '0.31',
		blurb		=> 'This plugin check number of each processus'
				.'monitored by a Net-SNMP agent.',
		plugin		=> $progname,
		extra		=> "\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
				."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
	);

# Add warning and critical threshold options
$ucdsnmp_prtable->add_thresholds_opts(
		required	=>	1,
	);

# Add perdata option
$ucdsnmp_prtable->add_perfdata_opts();

# Add name and regexp options
$ucdsnmp_prtable->add_name_opts(
  		description	=> "Name of requested processus.",
	);

$ucdsnmp_prtable->getopts;

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$ucdsnmp_prtable->connect();

# 
# Fill OID list for request
#
my %oids_named_list = (
		name		=>	'prNames',
		maximum		=>	'prMax',
		minimum		=>	'prMin',
		number 		=>	'prCount',
		error		=>	'prErrorFlag',
		message 	=>	'prErrMessage',
	);

#
# SNMP request
#
$resultat = $ucdsnmp_prtable->get_named_table_by_name( 
		name		=> 	$ucdsnmp_prtable->opts->name,
		oid_names	=> 	'prNames',
		oids		=> 	\%oids_named_list, 
	  );

if (not defined($$resultat{'name'}) ) {
	$ucdsnmp_prtable->plugin_die(
			"Can't find any processus that matches "
			. $ucdsnmp_prtable->opts->name,
		);
}
  
if ( $$resultat{'error'} ne 'noError' ) {
	$output = $$resultat{'message'};
	$status = CRITICAL;
}
else {

	$output = "Number of processus ". $$resultat{'name'} ." ";

	$status = $ucdsnmp_prtable->check_threshold(
			check		=> $$resultat{'number'},
			warning		=> $ucdsnmp_prtable->opts->warning,
			critical	=> $ucdsnmp_prtable->opts->critical,
		);

	switch( $status ) {
		case OK	{
				$output .= "is under threshold.";
			}
		case WARNING {
				$output .= "is larger than "
						. $ucdsnmp_prtable->opts->warning
						. " $uom";
				}
		case CRITICAL {
				$output .= "is larger than "
						. $ucdsnmp_prtable->opts->critical
						. " $uom";
				}
	}
	
	$ucdsnmp_prtable->add_message(
			$status,
			$output,
		);

	$output = "Number of processus ". $$resultat{'name'} ." ";

	if ( $$resultat{'maximum'} > 0 ) {
		$status = $ucdsnmp_prtable->check_threshold(
				check		=> $$resultat{'number'},
				critical	=> $$resultat{'maximum'},
			);
		$ucdsnmp_prtable->add_message(
				$status,
				$output 
					."is larger than "
					. $$resultat{'maximum'},
			);

	}

	if ( $$resultat{'minimum'} > 0 ) {
		$status = $ucdsnmp_prtable->check_threshold(
				check		=> $$resultat{'minimum'},
				critical	=> $$resultat{'number'},
			);
	}

	if ( $ucdsnmp_prtable->opts->perfdata ) {
		$$resultat{'name'} =~ s|.*/(.*)$|$1|g;
		$ucdsnmp_prtable->add_perfdata(
				label		=> $$resultat{'name'},
				value		=> $$resultat{'number'},
				uom		=> $uom,
				threshold	=> $ucdsnmp_prtable->{'threshold'},
			);
	}
}

#==========================================================================
# Exit with Monitoring codes
#==========================================================================

($status,$output) = $ucdsnmp_prtable->check_messages;
$ucdsnmp_prtable->plugin_exit(
   		$status,
		$output,
	);

