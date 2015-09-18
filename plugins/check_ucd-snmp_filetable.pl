#! /usr/bin/perl -w
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check the value of each file monitored by a 
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

my $i_filetable	= undef;

my $uom			= "kB";
my $error		= undef;
my $output		= undef;
my $status		= UNKNOWN;
my $table		= undef;
my $resultat		= undef;

#==========================================================================
# Options
#==========================================================================
my $progname = basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $ucdsnmp_filetable = Monitoring::Plugin::SNMP->new (
	shortname	=> 'UCD-SNMP file table',
	version		=> '0.31',
	blurb		=> 'This plugin check size of files monitored by a Net-SNMP agent.',
	plugin		=> $progname,
	extra		=> "\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
			."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
);

# Add warning and critical threshold options
$ucdsnmp_filetable->add_thresholds_opts();

# Add perdata option
$ucdsnmp_filetable->add_perfdata_opts();

# Add name and regexp options
$ucdsnmp_filetable->add_name_opts(
  		description	=> "Name of requested file.",
	);

$ucdsnmp_filetable->getopts;

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$ucdsnmp_filetable->connect();

# 
# Fill OID list for request
#
my %oids_named_list = (
		taille		=>	'fileSize',
		maximum		=>	'fileMax',
		erreur		=>	'fileErrorFlag',
		message 	=>	'fileErrorMsg',
	);

#
# SNMP request
#
$resultat = $ucdsnmp_filetable->get_named_table_by_name( 
							name		=> $ucdsnmp_filetable->opts->name,
							oid_names	=> 'fileName',
							oids		=> \%oids_named_list, 
					  );

$output = $$resultat{'sortie'};
if (not defined($output) ) {
	$ucdsnmp_filetable->plugin_die(
			"Can't find any file that matches ". 
				$ucdsnmp_filetable->opts->name,
		);
}
  
if ( not $$resultat{'erreur'} ) {
	$output = $$resultat{'message'};
	$status = CRITICAL;
}
else {
	if ( defined( $ucdsnmp_filetable->opts->warning ) 
		and defined( $ucdsnmp_filetable->opts->critical ) ) {

		$output = "Size of file named ". $ucdsnmp_filetable->opts->name ." ";

		$status = $ucdsnmp_filetable->check_threshold(
					check		=> $$resultat{'taille'},
				);

		switch( $status ) {
			case OK	{
						$output .= "is under threshold.";
					}
			case WARNING {
						$output .= "is larger than "
								. $ucdsnmp_filetable->opts->warning
								. " $uom";
					}
			case CRITICAL {
						$output .= "is larger than "
								. $ucdsnmp_filetable->opts->critical
								. " $uom";
					}
		}

		if ( $ucdsnmp_filetable->opts->perfdata ) {
			$$resultat{'name'} =~ s|.*/(.*)$|$1|g;
			$ucdsnmp_filetable->add_perfdata(
					label		=> $$resultat{'name'},
					value		=> $$resultat{'taille'},
					uom			=> $uom,
					threshold	=>$ucdsnmp_filetable->{'threshold'},
				);
		}
	}
	else {
		$output = "Missing warning or critical option(s).";
	}
}

$ucdsnmp_filetable->plugin_exit(
   		$status,
		$output,
	);

