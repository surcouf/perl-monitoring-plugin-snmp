#!/usr/bin/perl
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check I/O disk statistics through a {UCD|Net}-SNMP agent.
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


#==========================================================================
# Options
#==========================================================================
my $progname = basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $plugin = Monitoring::Plugin::SNMP->new (
		shortname	=> 	'UCD-SNMP diskio',
		version		=> 	'0.02',
		blurb		=> 	'This plugin check I/O disk statistics through a Net-SNMP agent.',
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
		description	=>	"Name of requested disk.",
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
		name		=>	'diskIODevice',
		ionread		=>	'diskIONRead',
		ionwritten	=>	'diskIONWritten',
		ioreads		=>	'diskIOReads',
		iowrites	=>	'diskIOWrites',
#		ionread		=>	'diskIONReadX',		# 64 bits
#		ionwritten	=>	'diskIONWrittenX',	# counters
	);

my $devices;

if ( defined( $plugin->opts->name ) ) {
	#
	# Get data based on device name 
	#
	$devices = $plugin->get_named_table_by_name( 
			name		=> $plugin->opts->name,
			oid_names	=> 'diskIODevice',
			oids		=> \%oids_named_list, 
		);
}
else {
	$devices = $plugin->get_named_table( %oids_named_list );
}

foreach my $device ( @$devices ) {

	my $mesg	= $$device{'name'} .": ";
	my $state	= OK;

	foreach my $iovars ( keys %$device ) {

		next if ( $iovars eq 'name' );

		my $uom 	= undef;
		my $name	= $iovars;
		my $value 	= $$device{ $iovars };

		$state	= $plugin->check_threshold(
					$value,
				);

		$mesg .= "$name = $value";

		if ( $name =~ /ion(read|written)/ ) {
			$mesg .= " bytes";
			$uom = "b";
		}
		$mesg .= ", ";
	
		if ( defined( $plugin->opts->perfdata ) ) {
		
			$plugin->add_perfdata(
					label		=>	$$device{'name'} ."_". $name,
					value		=>	$value,
					uom			=>	$uom,
					threshold	=>	$plugin->{'thresholds'},
				);
		}
	}
	$mesg =~ s/, $/\n/;

	$plugin->add_message(
			$state,
			$mesg,
		);

}

my ($status, $output) = $plugin->check_messages();

$plugin->nagios_exit(
		message		=> $output,
		return_code	=> $status,
	);

