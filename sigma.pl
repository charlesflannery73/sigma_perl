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
sub generate();
sub details();
sub export();

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
my $generate;
my $details;
my $export;
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
  "update=s"    => \$update,
  "search=s"    => \$search,
  "regex=s"     => \$regex,
  "export"      => \$export,
  "type=s"      => \$type,
  "generate=s"  => \$generate,
  "details=s"   => \$details,
  "sig-text=s"  => \$sig_text,
  "sig-file=s"  => \$sig_file,
  "reference=s" => \$reference,
  "status=s"    => \$status,
  "comment=s"   => \$comment)
or usage();

if (defined $comment) {
  chomp $comment;
}
if (defined $reference) {
 chomp $reference;
}
if ($sig_text) {
  chomp $sig_text;
}

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
} elsif (defined $generate) {
  generate();
} elsif (defined $details) {
  details();
} elsif (defined $export) {
  export();
} else {
  usage();
}

clean_up();

exit(0);


sub add_type() {
  if ($add_type !~ /^[A-Za-z0-9_-]*$/) {
    die("Invalid characters found, use only [A-Za-z0-9_-]\n");
  }
  # database ensures sig_type is unique, allow db to handle errors
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
      print "either --sig-text or --sig-file, not both\n";
      return;
    }
  } elsif (defined $sig_file) {
    if (!-e $sig_file) {
      print "file $sig_file doesn't exist\n";
      return;
    }
    open FILE, "<$sig_file";
    $sig_text = do { local $/; <FILE> };
    $sig_text =~ s/\'/\\\'/g;
    chomp $sig_text;
  } else {
    print "--sig-text or --sig-file needs to be defined\n";
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
  $reference =~ s/\'/\\\'/g;

  # add username if no comment
  if (not defined $comment) {
    $comment = "Added by $username";
  }
  $comment =~ s/\'/\\\'/g;

  # first check if signature already exists and report the sig_name
  my $sth = $dbh->prepare("SELECT sig_name from signatures left join sig_name on signatures.sig_id = sig_name.id where sig_text = '$sig_text'");
  $sth->execute;
  if ($sth->rows) {
    print "The signature\n";
    print "-------------\n";
    print "$sig_text\n";
    print "-------------\n";
    my $ref = $sth->fetchrow_hashref();
    print "already exists $ref->{'sig_name'}\n";
    $sth->finish;
    clean_up();
  }
  $sth->finish;

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
  $sth = $dbh->prepare("SELECT id from sig_name where sig_name = '$add_sig'");
  $sth->execute;
  if (!$sth->rows) {
    print "Couldn't find $add_sig in database\n";
    $sth->finish;
    clean_up();
  }
  my $ref = $sth->fetchrow_hashref();
  $sig_id = $ref->{'id'};
  $sth->finish;

  $dbh->do("INSERT into signatures (sig_id, sig_type_id, sig_text, reference, status) VALUES ($sig_id, $type_id, '$sig_text', '$reference', '$status')");
  print "Added $add_sig\n";

  # insert comments
  $dbh->do("INSERT into comments (sig_id, comment) VALUES ($sig_id, '$comment')");

}

sub update() {
  my $sig_id;
  my $old_ref;
  my $old_status;
  my $old_sig_text;

  # check sig exists before updating and get id
  my $sth = $dbh->prepare("SELECT * from sig_name where sig_name = '$update'");
  $sth->execute;
  if (!$sth->rows) {
    print "Couldn't find $update in database\n";
    $sth->finish;
  }
  my $ref = $sth->fetchrow_hashref();
  $sig_id = $ref->{'id'};
  $sth->finish;

  # check at least one thing to update
  if (not defined $comment || $reference || $sig_text || $status) {
    print "must update either comment, reference, sig_text or status\n";
    usage();
  }

  # get old values for auto adding to comments - to keep history
  $sth = $dbh->prepare("SELECT * from signatures where sig_id = $sig_id");
  $sth->execute;
  if (!$sth->rows) {
    print "Couldn't find $sig_id in database\n";
    $sth->finish;
  }
  $ref = $sth->fetchrow_hashref();
  $old_ref = $ref->{'reference'};
  $old_status = $ref->{'status'};
  $old_sig_text = $ref->{'sig_text'};
  $sth->finish;

  if (not defined $comment) {
    $comment = "Updated by $username";
  } else {
    $comment = "Updated by $username: $comment";
  }

  #build query depending on what is to be updated, also build comment field
  if (defined $sig_text or defined $reference or defined $status) {
    my $query = "UPDATE signatures SET ";
    if (defined $sig_text) {
      $sig_text =~ s/\'/\\\'/g;
      $query .= "sig_text = '$sig_text', ";
      $comment .= "\nold sig_text=$old_sig_text";
    }
    if (defined $reference) {
      $reference =~ s/\'/\\\'/g;
      $query .= "reference = '$reference', ";
      $comment .= "\nold reference=$old_ref";
    }
    if (defined $status) {
      $status =~ s/\'/\\\'/g;
      $query .= "status = '$status', ";
      $comment .= "\nold status=$old_status";
    }
    $query = substr($query, 0, -2);
    $query .= " WHERE sig_id = '$sig_id'";
    $dbh->do("$query");
  }

  # add comments
  $comment =~ s/\'/\\\'/g;
  $dbh->do("INSERT into comments (sig_id, comment) VALUES ($sig_id, '$comment')");
}

sub search() {

  $search =~ s/\'/\\\'/g;
  my $found = 0;

  # search in sig_text
  my $sth = $dbh->prepare("SELECT sig_name,sig_text from signatures left join sig_name on signatures.sig_id = sig_name.id where sig_text like '%$search%'");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "sig_text | $ref->{'sig_name'} | $ref->{'sig_text'}\n";
    }
  }
  $sth->finish;

  # search in sig_name
  $sth = $dbh->prepare("SELECT sig_name from sig_name where sig_name like '%$search%';");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "name | $ref->{'sig_name'}\n";
    }
  }
  $sth->finish;

  # search in reference
  $sth = $dbh->prepare("SELECT sig_name,reference from signatures left join sig_name on signatures.sig_id = sig_name.id where reference like '%$search%'");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "reference | $ref->{'sig_name'} | $ref->{'reference'}\n";
    }
  }
  $sth->finish;

  # search in comments
  $sth = $dbh->prepare("SELECT sig_name,comment from signatures left join sig_name on signatures.sig_id = sig_name.id left join comments on signatures.sig_id = comments.sig_id where comment like '%$search%'");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "comment | $ref->{'sig_name'} | $ref->{'comment'}\n";
    }
  }
  $sth->finish;

  if (!$found) {
    print "search string \"$search\" is not found\n";
  }

}

sub regex() {

  $regex =~ s/\'/\\\'/g;
  my $found = 0;

  # search in sig_text
  my $sth = $dbh->prepare("SELECT sig_name,sig_text from signatures left join sig_name on signatures.sig_id = sig_name.id where sig_text REGEXP '$regex'");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "sig_text | $ref->{'sig_name'} | $ref->{'sig_text'}\n";
    }
  }
  $sth->finish;

  # search in sig_name
  $sth = $dbh->prepare("SELECT sig_name from sig_name where sig_name REGEXP '$regex';");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "name | $ref->{'sig_name'}\n";
    }
  }
  $sth->finish;

  # search in reference
  $sth = $dbh->prepare("SELECT sig_name,reference from signatures left join sig_name on signatures.sig_id = sig_name.id where reference REGEXP '$regex'");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "reference | $ref->{'sig_name'} | $ref->{'reference'}\n";
    }
  }
  $sth->finish;

  # search in comments
  $sth = $dbh->prepare("SELECT sig_name,comment from signatures left join sig_name on signatures.sig_id = sig_name.id left join comments on signatures.sig_id = comments.sig_id where comment REGEXP '$regex'");
  $sth->execute;
  if ($sth->rows) {
    $found = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
      print "comment | $ref->{'sig_name'} | $ref->{'comment'}\n";
    }
  }
  $sth->finish;

  if (!$found) {
    print "regex \"$regex\" is not found\n";
  }

}

sub generate() {

  # get the type id
  my $sth = $dbh->prepare("SELECT id from types where sig_type = '$generate'");
  $sth->execute;
  if ($sth->rows != 1) {
    print "type $generate doesn't exist in the database\n";
    $sth->finish;
    return;
  }
  my $ref = $sth->fetchrow_hashref();
  my $type_id = $ref->{'id'};
  $sth->finish;

  if (!$status) {
    $status = "enabled";
  }

  # print sigs
  $sth = $dbh->prepare("SELECT sig_text from signatures where sig_type_id = $type_id and status = '$status';");
  $sth->execute;
  if ($sth->rows) {
    while (my $ref = $sth->fetchrow_hashref()) {
      print "$ref->{'sig_text'}\n";
    }
  }
  $sth->finish;
}

sub details() {

  # print all except comments
  my $sth = $dbh->prepare("SELECT * from signatures left join sig_name on signatures.sig_id = sig_name.id where sig_name = '$details'");
  $sth->execute;
  my $ref = $sth->fetchrow_hashref();
  if ($sth->rows) {
    print "$details | $ref->{'status'} | $ref->{'reference'} | $ref->{'modified'} | $ref->{'sig_text'}\n";
  } else {
    print "$details\ndoesn't exist in the database\n";
    $sth->finish;
    return;
  }
  $sth->finish;

  # print all the comments
  $sth = $dbh->prepare("SELECT sig_name,comment,ts from signatures left join sig_name on signatures.sig_id = sig_name.id left join comments on comments.sig_id = sig_name.id where sig_name.sig_name = '$details'");
  $sth->execute;
  while (my $ref = $sth->fetchrow_hashref()) {
    print "comment | $ref->{'ts'} | $ref->{'comment'}\n";
  }
  $sth->finish;
}

sub export() {

  my $sig_name;
  my $sth = $dbh->prepare("SELECT sig_type,id from types");
  $sth->execute;
  if ($sth->rows) {
    while (my $type_ref = $sth->fetchrow_hashref()) {
      print "./sigma.pl --add-type $type_ref->{'sig_type'}\n";
      my $sth2 = $dbh->prepare("SELECT * from signatures where sig_type_id = $type_ref->{'id'}");
      $sth2->execute;
      # print all the sigs foreach type
      if ($sth2->rows) {
        while (my $sig_ref = $sth2->fetchrow_hashref()) {
          my $sth3 = $dbh->prepare("SELECT sig_name from sig_name where id = $sig_ref->{'sig_id'}");
          $sth3->execute;
          my $name_ref = $sth3->fetchrow_hashref();
          $sig_name = $name_ref->{'sig_name'};
          print "./sigma.pl --add-sig $sig_name --type '$type_ref->{'sig_type'}' --reference '$sig_ref->{'reference'}' --status '$sig_ref->{'status'}' --sig-text '$sig_ref->{'sig_text'}'\n";
          
          # print all comments foreach sig
          $sth3 = $dbh->prepare("SELECT comment from comments where sig_id = $sig_ref->{'sig_id'}");
          $sth3->execute;
          if ($sth3->rows) {
            while (my $comment_ref = $sth3->fetchrow_hashref()) {
              print "./sigma.pl --update $sig_name --comment '$comment_ref->{'comment'}'\n";
            }
          }
        }
      }
    }
  }
  $sth->finish;
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
--add-type type-name
--add-sig [blank=auto|user-defined] --type=type-name [--sig-text="rule text here"|--sig-file=/path/to/sigfile] [--status=enabled|disabled|testing] [--reference="external_ref"] [--comment=auto|"user-defined"]
--update sig-name [--sig-text|--status|--reference|--comment] [comment=auto] 
--search string [searches in sig_name, sig-text, reference and comment]
--regex regex [regex search in sig_name, sig-text, reference and comment]
--generate type-name [--status=enabled|disabled|testing]
--details sig_name
--export 
';
  die($usage);
}
