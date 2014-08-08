#!/usr/bin/perl

use strict;
use warnings;

my @user_agents = `/usr/local/bin/sigma.pl --generate user_agent`;

foreach my $user_agent (@user_agents) {
  chomp $user_agent;
  my $result = `grep -Fw "$user_agent" /data/bro/http.log`;
  if ($result) {
    print "FOUND UA hit for $user_agent\n";
  }
}
