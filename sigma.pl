#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use DBI;
use DBD::mysql;

#
# Subroutines
#

# actions
sub add_type();
sub add_sig();
sub update();
sub search();
sub regex();
sub list();

sub connect_db();

#
# Options
#
my $add_sig;
my $update;
my $search;
my $regex;
my $list;
my $add_type;
my $type;
my $sig_text;
my $sig_file;
my $reference;
my $status;
my $comment;

my $my_cnf = '~/.my.cnf';

my $usage = 'Usage:
--add-type snort
--add-sig [blank=auto|user-defined] --type=snort [--sig-text="snort rule here"|--sig-file=/path/to/sigfile] [--status=enabled|disabled|testing] [--reference="external_ref"] [--comment=auto|"user-defined"]
--update sig-name [--sig-text|--status|--reference|--comment] [comment=auto] 
--search string [searches in sig-text, reference and comment]
--regex regex [regex search in sig-text, reference and comment]
--list [dumps all sigs]
--list snort [dumps all of selected type]
';

GetOptions (
  "add-type=s"  => \$add_type,
  "add-sig"     => \$add_sig,
  "update"      => \$update,
  "search=s"    => \$search,
  "regex=s"     => \$regex,
  "list"        => \$list,
  "type=s"      => \$type,
  "sig-text=s"  => \$sig_text,
  "sig-file=s"  => \$sig_file,
  "reference=s" => \$reference,
  "status=s"    => \$status,
  "comment=s"   => \$comment)
or die("Error in command line arguments\n$usage");


#
# Main
#

# select action
if (defined $add_type) {
  add_type();
} elsif (defined $add_sig) {
  add_sig();
} elsif (defined $update) {
  update();
} elsif (defined $search) {
  search();
} elsif (defined $regex) {
  regex();
} elsif (defined $list) {
  list();
}

exit(0);


sub add_type() {
  if ($add_type !~ /^[A-Za-z0-9_-]*$/) {
    die("Invalid characters found, use only [A-Za-z0-9_-]\n");
  }

  my $dbh = connect_db();
  $dbh->do("INSERT into types SET sig_type = '$add_type'");
  $dbh->disconnect();
}

sub add_sig() {

}

sub update() {

}

sub search() {

}

sub regex() {

}

sub list() {

}

sub connect_db() {
  my $dsn =
    "DBI:mysql:;" . 
    "mysql_read_default_file=$my_cnf";

  my $dbh = DBI->connect(
    $dsn, 
    undef, 
    undef, 
    {RaiseError => 1}
  ) or  die "DBI::errstr: $DBI::errstr";
  return $dbh;
}

