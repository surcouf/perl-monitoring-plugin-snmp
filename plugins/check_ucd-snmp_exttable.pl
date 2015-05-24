#!/usr/bin/perl
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check the value of each extensibles command of a 
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
# Version 0.04 (2008/03):
# - Port to Monitoring::Plugin::SNMP
# Version 0.03 (2006/10):
# - Add SNMPv3 support
# Version 0.02 (2006/02):
# - Add perfdata support
# Version 0.01 (2006/02):
# - First implementation
# Author: Raphaël 'SurcouF' Bordet
#====================================================================

use strict;
use Monitoring::Plugin::SNMP;
use File::Basename qw(basename);

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

my $ucdsnmp_exttable = Monitoring::Plugin::SNMP->new (
		shortname	=> 	'UCD-SNMP extension table',
		version		=> 	'0.31',
		blurb		=> 	'This plugin check execution of extensions from a Net-SNMP agent.',
		plugin		=> 	$progname,
		extra		=> 	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
					."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
	);

# Add warning and critical threshold options
$ucdsnmp_exttable->add_thresholds_opts();

# Add perdata option
$ucdsnmp_exttable->add_perfdata_opts();

# Add name and regexp options
$ucdsnmp_exttable->add_name_opts(
		description	=>	"Name of requested extension.",
	);

$ucdsnmp_exttable->getopts;

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$ucdsnmp_exttable->connect();

# 
# Fill OID list for request
#
my %oids_named_list = (
		resultat	=>	'extResult',
		sortie		=>	'extOutput',
	);

#
# SNMP request
#
my $commands = $ucdsnmp_exttable->get_named_table_by_name( 
						name		=> $ucdsnmp_exttable->opts->name,
						oid_names	=> 'extNames',
						oids		=> \%oids_named_list, 
					  );

foreach my $resultat ( @$commands ) {

	$output = $$resultat{'sortie'};
	if (not defined($output) ) {
		$ucdsnmp_exttable->nagios_die(
				"Can't find any extension that matches ". 
					$ucdsnmp_exttable->opts->name,
			);
	}
  
	$status = $$resultat{'resultat'};
	if (not defined( $status ) ) {
		$output = "plugin output is out of bound (". $$resultat{'resultat'} .")";
		$status = UNKNOWN;
	}
}

print $output ."\n";
exit $status;

