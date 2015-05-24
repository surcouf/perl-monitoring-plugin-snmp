#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Monitoring::Plugin::SNMP' );
}

diag( "Testing Monitoring::Plugin::SNMP $Monitoring::Plugin::SNMP::VERSION, Perl $], $^X" );
