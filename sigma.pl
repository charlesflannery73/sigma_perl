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
sub clean_up();
sub usage();

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
my $dbh;

my $my_cnf = '~/.my.cnf';
my $username = getpwuid( $< );

GetOptions (
  "add-type=s"  => \$add_type,
  "add-sig:s"   => \$add_sig,
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
or usage();

#
# Main
#

connect_db();

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
} else {
  usage();
}

clean_up();

exit(0);


sub add_type() {
  if ($add_type !~ /^[A-Za-z0-9_-]*$/) {
    die("Invalid characters found, use only [A-Za-z0-9_-]\n");
  }
  $dbh->do("INSERT into types SET sig_type = '$add_type'");
}

sub add_sig() {

  #check type exists and get type id
  my $type_id;
  if (defined $type) {
    my $sth = $dbh->prepare("SELECT id from types where sig_type = '$type'");
    $sth->execute;
    if ($sth->rows != 1) {
      print "type $type doesn't exist in the database, try another or use --add-type\n";
      $sth->finish;
      return;
    }
    my $ref = $sth->fetchrow_hashref();
    $type_id = $ref->{'id'};
    $sth->finish;
  } else {
    print "--type is not defined\n";
    return;
  }

  #check either sig-text or sig-file is defined, if file then load into sig_text
  if (defined $sig_text) {
    if (defined $sig_file) {
      print "either --sig-type or --sig-file, not both\n";
      return;
    }
  } elsif (defined $sig_file) {
    if (!-e $sig_file) {
      print "file $sig_file doesn't exist\n";
      return;
    }
    open FILE, "<$sig_file";
    $sig_text = do { local $/; <FILE> };
  } else {
    print "--sig-type or --sig-file needs to be defined\n";
    return;
  }

  # check for status, set default
  if (not defined $status) {
    $status = "enabled";
  }

  # check for reference
  if (not defined $reference) {
    $reference = "none";
  }

  # add username if no comment
  if (not defined $comment) {
    $comment = "Added by $username";
  }

  # auto generate sig_name if not provided
  if ($add_sig eq '') {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); 
    my $date = sprintf("%04d%02d%02d", $year+1900, $mon+1, $mday);
    $add_sig = "sig-$type-$date-";
    # check that database for the next number in the sequence
    my $sth = $dbh->prepare("SELECT sig_name from sig_name where sig_name like '$add_sig%' order by sig_name DESC limit 1");
    $sth->execute;
    if (!$sth->rows) {
      $add_sig .= "0001";
    } else {
      my $ref = $sth->fetchrow_hashref();
      my $last = $ref->{'sig_name'};
      $last =~ s/$add_sig//;
      $last++;
      if ($last > 9999) {
        print "reached limit of auto numbering, wait a day or specify your own\n";
        $sth->finish;
        clean_up();
      }
      $last = sprintf("%04d", $last);
      $add_sig .= $last;
    }
    $sth->finish;
  }

  my $sig_id;
  #print "adding sig_name $add_sig to sig_name table\n";
  $dbh->do("INSERT into sig_name SET sig_name = '$add_sig'");
  my $sth = $dbh->prepare("SELECT id from sig_name where sig_name = '$add_sig'");
  $sth->execute;
  if (!$sth->rows) {
    print "Error finding $add_sig in database";
    $sth->finish;
    clean_up();
  }
  my $ref = $sth->fetchrow_hashref();
  $sig_id = $ref->{'id'};
  $sth->finish;

  #TODO
  print "TODO - need to escape certain characters here\n";
  $dbh->do("INSERT into signatures (sig_id, sig_type_id, sig_text, reference, status) VALUES ($sig_id, $type_id, '$sig_text', '$reference', '$status')");
  print "Added $add_sig\n";
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

  $dbh = DBI->connect(
    $dsn, 
    undef, 
    undef, 
    {RaiseError => 1}
  ) or  die "DBI::errstr: $DBI::errstr";
}

sub clean_up() {
  $dbh->disconnect();
  exit(0);
}

sub usage() {

  my $usage = 'Usage:
--add-type snort
--add-sig [blank=auto|user-defined] --type=snort [--sig-text="snort rule here"|--sig-file=/path/to/sigfile] [--status=enabled|disabled|testing] [--reference="external_ref"] [--comment=auto|"user-defined"]
--update sig-name [--sig-text|--status|--reference|--comment] [comment=auto] 
--search string [searches in sig-text, reference and comment]
--regex regex [regex search in sig-text, reference and comment]
--list [dumps all sigs]
--list snort [dumps all of selected type]
';
  die($usage);
}
