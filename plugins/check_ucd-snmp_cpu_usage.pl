#! /usr/bin/perl -w
# vim: fenc=utf-8:ff=unix:ft=help:norl:et:ci:pi:sts=0:sw=8:ts=4:tw=80:syntax=perl:
#====================================================================
# What's this ?
#====================================================================
# This plugin check the CPU usage for User, Nice, System and Idle processus
# through a {UCD|Net}-SNMP agent.
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

my $output			= undef;
my $status			= undef;

my $total			= undef;

my %diff			= ();
my %percent			= ();

my $waiting 			= 10; # Delay between two SNMP requests, in microseconds.

#==========================================================================
# Options
#==========================================================================
my $progname 			= basename($0);

#==========================================================================
# Create Monitoring::Plugin::SNMP object
#==========================================================================

my $ucdsnmp_cpu_usage		= Monitoring::Plugin::SNMP->new (
	shortname	=> 	'UCD-SNMP CPU usage',
	version		=> 	'0.01',
	blurb		=> 	'This plugin check CPU usage from a Net-SNMP agent.',
	plugin		=> 	$progname,
	extra		=> 	"\n Copyright (c) 2011 Raphaël 'SurcouF' Bordet"
				."\n Report bugs to: Raphaël 'SurcouF' Bordet <surcouf\@debianfr.net>",
);

# Add warning and critical threshold options
$ucdsnmp_cpu_usage->add_thresholds_opts(
		required	=>	1,
	);

# Add perdata option
$ucdsnmp_cpu_usage->add_perfdata_opts;

$ucdsnmp_cpu_usage->getopts;

#=========================================================================
# Main
#=========================================================================

#
# Connect to SNMP agent
#
$ucdsnmp_cpu_usage->connect();

# 
# Fill OID list for request
#
my @oids_list = (
		'ssCpuRawUser',
		'ssCpuRawSystem',
		'ssCpuRawIdle',
		'ssCpuRawNice',
	);

#
# First SNMP request
#
my @table = $ucdsnmp_cpu_usage->get_request(
			oid	=>	\@oids_list,
		);
my $count = 0;
foreach my $oid ( @oids_list ) {
	$diff{ $oid } = $table[$count];
	$count++;
}

sleep $waiting;

#
# Second SNMP request
#
@table = $ucdsnmp_cpu_usage->get_request(
			oid	=>	\@oids_list,
		);
$count = 0;
foreach my $oid ( @oids_list ) {
	$diff{ $oid } = $table[$count] - $diff{$oid};
	$total += $diff{$oid};
	$count++;
}

#
# Results process
#
if ( $total > 0 ) {
	foreach my $oid ( keys %diff ) {
		my $oid_name = $oid;
		$oid_name =~ s/ssCpuRaw//;
		$oid_name = lc($oid_name);

		$percent{$oid} = ( $diff{$oid} / $total ) * 100;

		my $value = sprintf("%.2f",$percent{ $oid });

		# idle must be always have OK status
		if ( $oid_name eq 'idle' ) {
			$ucdsnmp_cpu_usage->add_message(
					OK,
					"$oid_name=$value% ",
				);
		}
		else {
			$ucdsnmp_cpu_usage->add_message(
					$ucdsnmp_cpu_usage->check_threshold( $value ),
					"$oid_name=$value% ",
				);
		}

		if ( defined( $ucdsnmp_cpu_usage->opts->perfdata ) ) {
			my $label = $oid_name . "_cpu_usage";
			$ucdsnmp_cpu_usage->add_perfdata(
					label		=> $label,
					value		=> $value,
					uom		=> '%',
					threshold	=> $ucdsnmp_cpu_usage->{'threshold'},
				);
		}
	}
}
else {
	$ucdsnmp_cpu_usage->plugin_die( "No difference between checks (delay: $waiting)..." );
}

#==========================================================================
# Exit with Monitoring codes
#==========================================================================

($status, $output) = $ucdsnmp_cpu_usage->check_messages();
$ucdsnmp_cpu_usage->plugin_exit(
		message		=> $output,
		return_code	=> $status,
	);

