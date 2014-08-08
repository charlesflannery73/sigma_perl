#!/usr/bin/perl

use strict;
use warnings;

my @email_addresses = `/usr/local/bin/sigma.pl --generate email_address`;

foreach my $email_address (@email_addresses) {
  chomp $email_address;
  my $result = `grep -Fw "$email_address" /data/bro/*.log`;
  if ($result) {
    print "FOUND email_address hit for $email_address\n";
  }
}
