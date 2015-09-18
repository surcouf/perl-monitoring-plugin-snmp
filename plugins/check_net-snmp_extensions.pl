#!/usr/bin/perl
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check the value of each extensibles command of a 
# {UCD|Net}-SNMP agent.
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
# Version 0.01 (2011/02):
# - First implementation
# Author: Raphaël 'SurcouF' Bordet
#====================================================================

use strict;
use Monitoring::Plugin::SNMP;
use File::Basename qw(basename);

my $error	= undef;
my $output	= undef;
my $status	= undef;
my $resultat	= undef;

#==========================================================================
# Options
#==========================================================================
my $progname	= basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $netsnmp_extensions = Monitoring::Plugin::SNMP->new (
		shortname	=> 	'Net-SNMP extension table',
		version		=> 	'0.31',
		blurb		=> 	'This plugin check execution of extensions from a Net-SNMP agent.',
		plugin		=> 	$progname,
		extra		=> 	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
					."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
	);

# Add warning and critical threshold options
$netsnmp_extensions->add_thresholds_opts();

# Add perdata option
$netsnmp_extensions->add_perfdata_opts();

# Add name and regexp options
$netsnmp_extensions->add_name_opts(
		description	=>	"Name of requested extension.",
		required	=>	1,
	);

$netsnmp_extensions->getopts;

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$netsnmp_extensions->connect();

# 
# Fill OID list for request
#
my %oids_named_list = (
		resultat	=>	'nsExtendResult',
		sortie		=>	'nsExtendOutput1Line',
		lines		=>	'nsExtendOutNumLines',
	);

#
# SNMP request
#
my $i_extend =  $netsnmp_extensions->get_index_by_name(
			name		=> $netsnmp_extensions->opts->name,
			oid_names	=> 'nsExtendCommand',
		  );

$resultat = $netsnmp_extensions->get_named_table_by_index( 
			index		=> $i_extend,
			oids		=> \%oids_named_list, 
		  );

$output = $$resultat{'sortie'};
if (not defined($output) ) {
	$netsnmp_extensions->plugin_die(
			"Can't find any extension that matches ". 
				$netsnmp_extensions->opts->name,
		);
}
  
if ( $$resultat{'lines'} > 1 ) {
	$netsnmp_extensions->add_message(
			UNKNOWN,
			"Not implemented yet.",
		);
}
else {
	$status = $$resultat{'resultat'};
	if (not defined( $status ) ) {
		$output = "plugin output is out of bound (". $$resultat{'resultat'} .")";
		$status = UNKNOWN;
	}

	$netsnmp_extensions->add_message(
			$status,
			$output,
		);
}

#==========================================================================
# Exit with Monitoring codes
#==========================================================================

($status, $output) = $netsnmp_extensions->check_messages();
$netsnmp_extensions->plugin_exit(
		message		=> $output,
		return_code	=> $status,
	);


