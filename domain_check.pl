#!/usr/bin/perl

use strict;
use warnings;

my @domains = `/usr/local/bin/sigma.pl --generate domain`;

foreach my $domain (@domains) {
  chomp $domain;
  my $result = `grep -Fw "$domain" /data/bro/*.log`;
  if ($result) {
    print "FOUND domain hit for $domain\n";
  }
}
