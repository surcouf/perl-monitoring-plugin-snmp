use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Monitoring::Plugin::SNMP',
    AUTHOR              => "Raphael 'SurcouF' Bordet <surcouf\@debianfr.net>",
    VERSION_FROM        => 'lib/Monitoring/Plugin/SNMP.pm',
    ABSTRACT_FROM       => 'lib/Monitoring/Plugin/SNMP.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Monitoring-Plugin-SNMP-*' },
);
