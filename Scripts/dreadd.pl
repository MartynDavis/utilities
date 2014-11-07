#!/usr/local/bin/perl -w

#
# 25-Nov-09 Display current status and % complete
#

use strict;
use warnings;

use Getopt::Std;
use LWP::UserAgent;
use File::Spec::Functions qw(rel2abs);

use constant DEFAULT_HOST => 'localhost';
use constant DEFAULT_PORTQUERY => 9000;
use constant DEFAULT_PORTINDEX => 9001;
use constant DEFAULT_PAUSE => 15;
use constant DEFAULT_TIMEOUT => 15;

my $ECHO_RESPONSE = 0;
my $ECHO_URL = 0;

sub getURL($$)
{
  my ($url, $timeout) = @_;
  my $result = '';

  my $ua = LWP::UserAgent->new;
  $ua->agent("Mozilla/8.0"); # pretend we are very capable browser
  $ua->timeout($timeout);

  print "\n$url\n\n" if $ECHO_URL;

  my $req = HTTP::Request->new(GET => $url);

  my $res = $ua->request($req);

  if ($res->is_success)
  {
    # Make the XML readable - Insert a line break between '>' and '<'
    $result = join(">\n<", split(/\>\</, $res->content));

    print "\n$result\n\n" if $ECHO_RESPONSE;
  }
  else
  {
    print "Error: " . $res->message ."\n";
  }

  return $result;
}

sub executeIndexAction($$)
{
  my ($url, $timeout) = @_;

  my $result = getURL($url, $timeout);

  return -1 if 0 == length($result);

  my $id = -1;
  $id = $1 if $result =~ m/INDEXID=(\d+)/;

  return $id;
}

sub waitForIndexAction($$$$$)
{
  my ($host, $portQuery, $id, $timeout, $pause) = @_;
  my $rc = 0;

  return $rc if $id <= 0;
  
  my $url = "http://$host:$portQuery/?Action=indexergetstatus&index=$id";
  
  print "Waiting for index request $id to complete\n\n";

  while (1)
  {
    my $result = getURL($url, $timeout);
    my $description = '';
    my $docIdFrom = 0;
    my $docIdTo = 0;
	my $duration = 0;
	my $percentage = 0;
	my $processed = 0;
	my $deleted = 0;

    last if 0 == length($result);
    
    my $status = $1 if $result =~ m/<status>(-{0,1}\d+)<\/status>/i;

    if (not defined $status)
    {
      print "Error: Unable to get status for index request $id\n";
      last;
    }
    
    $description = $1 if $result =~ m/<description>(.*)<\/description>/;
    
    if ($result =~ m/<docidrange>(\d+)-(\d+)<\/docidrange>/)
    {
      $docIdFrom = $1;
      $docIdTo = $2;
    }
	
	$duration = $1   if $result =~ m/<duration_secs>(\d+)<\/duration_secs>/i;
	$percentage = $1 if $result =~ m/<percentage_processed>(\d+)<\/percentage_processed>/i;
	$processed = $1  if $result =~ m/<documents_processed>(\d+)<\/documents_processed>/i;
	$deleted = $1    if $result =~ m/<documents_deleted>(\d+)<\/documents_deleted>/i;

	print "ID: $id - $description ($status)";
	print " - $duration seconds ($percentage%)" if ($duration > 0) || ($percentage > 0);
	if (($processed > 0) || ($deleted > 0))
	{
		print " processed: $processed" if $processed > 0;
		print " deleted: $deleted" if $deleted > 0;
		if ($docIdFrom > 0)
		{
		  print " (";
		  print "$docIdFrom" if $docIdTo == $docIdFrom;
		  print "$docIdFrom .. $docIdTo" if $docIdTo != $docIdFrom;
		  print ")";
		}
	}
	print "\n";
	
    if ((-1 == $status) || (-34 == $status))
    {
      # -1 == Finished
      # -34 == Pending commit
      $rc = 1;
      last;
    }
    
    if ((0 != $status) && (-7 != $status))
    {
      # Not queued (-7) or processing (0)
      print "\nError: Status is $status - $description\n";
      last;
    }

    sleep($pause);
  }
  
  return $rc;
}

sub addFile($$$$$$$$$)
{
  my ($host, $portQuery, $portIndex, $database, $file, $wait, $delete, $timeout, $pause) = @_;

  # Get the absolute path of the file, since IDOL needs this
  $file = rel2abs($file);

  my $url = "http://$host:$portIndex/DREADD?$file&KillDuplicates=REFERENCE";
  
  $url .= "&DELETE" if $delete;
  
  $url .= "&DREDbName=$database" if defined($database);
  
  my $id = executeIndexAction($url, $timeout);
  
  return 0 if -1 == $id;
  
  print "\nFile: $file (ID: $id)\n\n";
  
  return waitForIndexAction($host, $portQuery, $id, $timeout, $pause) if $wait;
  
  return 1;
}

sub syncDatabase($$$$$$)
{
  my ($host, $portQuery, $portIndex, $wait, $timeout, $pause) = @_;
  
  my $url = "http://$host:$portIndex/DRESYNC?";

  my $id = executeIndexAction($url, $timeout);

  return 0 if -1 == $id;
  
  print "Forcing an index sync (ID: $id)\n";
  
  return waitForIndexAction($host, $portQuery, $id, $timeout, $pause) if $wait;
  
  return 1;
}
my %Options;

if (!getopts('d:h:i:np:q:rst:ux', \%Options) || (($#ARGV + 1) <= 0))
{
  print "Usage: perl dreadd.pl [-d database] [-h host] [-i port] [-n] [-p seconds] [-q port]\n";
  print "                      [-r] [-s] [-t seconds] [-u] [-x] File ...\n";
  print "\n";
  print "       -d database - Database to add the file to, if it does not explicitly specify the database\n";
  print "       -h host     - DRE host to use (Default: " . DEFAULT_HOST . ")\n";
  print "       -i port     - DRE index port to use (Default: " . DEFAULT_PORTINDEX . ")\n";
  print "       -n          - Do not wait for index request to complete\n";
  print "       -p seconds  - Pause between indexergetstatus requests (Default: " . DEFAULT_PAUSE . ")\n";
  print "       -q port     - DRE query port to use (Default: " . DEFAULT_PORTQUERY . ")\n";
  print "       -r          - Echo response\n";
  print "       -s          - Perform DRESYNC if at least one file added successfully\n";
  print "       -t seconds  - HTTP timeout (Default: " . DEFAULT_TIMEOUT . ")\n";
  print "       -u          - Echo URL\n";
  print "       -x          - Delete file after processing\n";
  print "\n";
  print "       File        - IDX files to add to IDOL via DREADD indexing action\n";
  exit;
}

my $database;
my $host = DEFAULT_HOST;
my $portQuery = DEFAULT_PORTQUERY;
my $portIndex = DEFAULT_PORTINDEX;
my $timeout = DEFAULT_TIMEOUT;
my $pause = DEFAULT_PAUSE;
my $sync = 0;
my $wait = 1;
my $success = 0;
my $delete = 0;

# Allow environment variables to override static defaults
$database = $ENV{'DREADD_DATABASE'} if defined($ENV{'DREADD_DATABASE'});
$host = $ENV{'DREADD_HOST'} if defined($ENV{'DREADD_HOST'});
$portQuery = $ENV{'DREADD_PORT_QUERY'} if defined($ENV{'DREADD_PORT_QUERY'});
$portIndex = $ENV{'DREADD_PORT_INDEX'} if defined($ENV{'DREADD_PORT_INDEX'});
$pause = $ENV{'DREADD_PAUSE'} if defined($ENV{'DREADD_PAUSE'});
$timeout = $ENV{'DREADD_TIMEOUT'} if defined($ENV{'DREADD_TIMEOUT'});
$sync = $ENV{'DREADD_SYNC'} if defined($ENV{'DREADD_SYNC'});
$wait = $ENV{'DREADD_WAIT'} if defined($ENV{'DREADD_WAIT'});
$delete = $ENV{'DREADD_DELETE'} if defined($ENV{'DREADD_DELETE'});
$ECHO_URL = $ENV{'DREADD_ECHO_URL'} if defined($ENV{'DREADD_ECHO_URL'});
$ECHO_RESPONSE = $ENV{'DREADD_ECHO_RESPONSE'} if defined($ENV{'DREADD_ECHO_RESPONSE'});

# Allow command line to override defaults
$database = $Options{'d'} if defined($Options{'d'});
$host = $Options{'h'} if defined($Options{'h'});
$portQuery = $Options{'q'} if defined($Options{'q'});
$portIndex = $Options{'i'} if defined($Options{'i'});
$pause = $Options{'p'} if defined($Options{'p'});
$timeout = $Options{'t'} if defined($Options{'t'});
$sync = $Options{'s'} if defined($Options{'s'});
$wait = not $Options{'n'} if defined($Options{'n'});
$delete = $Options{'x'} if defined($Options{'x'});
$ECHO_URL = $Options{'u'} if defined($Options{'u'});
$ECHO_RESPONSE = $Options{'r'} if defined($Options{'r'});

print "Database: $database\n" if defined($database);
print "Host: $host\n" if defined($host);
print "Port Index: $portIndex\n" if defined($portIndex);
print "Port Query: $portQuery\n" if defined($portQuery);
print "Timeout: $timeout\n" if defined($timeout);
print "Pause: $pause\n" if defined($pause);
print "Sync: $sync\n" if defined($sync);
print "Wait: $wait\n" if defined($wait);
print "Delete: $delete\n" if defined($delete);

foreach (@ARGV)
{
  if (addFile($host, $portQuery, $portIndex, $database, $_, $wait, $delete, $timeout, $pause))
  {
    $success = 1;
  }
}

if ($sync && $success)
{
  # Force a sync of the database
  syncDatabase($host, $portQuery, $portIndex, $wait, $timeout, $pause);
}
