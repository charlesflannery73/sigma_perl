#!/usr/bin/perl

use strict;
use warnings;

my @ips = `/usr/local/bin/sigma.pl --generate ip`;

foreach my $ip (@ips) {
  chomp $ip;
  my $result = `grep -Fw "$ip" /data/bro/*.log`;
  if ($result) {
    print "FOUND IP hit for $ip\n";
  }
}
