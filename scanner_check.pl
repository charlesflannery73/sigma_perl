#!/usr/bin/perl

use strict;
use warnings;

my @scanners = `/usr/local/bin/sigma.pl --generate scanner`;

foreach my $scanner (@scanners) {
  chomp $scanner;
  my $result = `grep -Fw "$scanner" /data/bro/conn.log`;
  if ($result) {
    print "FOUND SCANNER hit for $scanner\n";
  }
}
