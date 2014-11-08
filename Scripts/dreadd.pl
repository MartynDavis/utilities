#!/usr/bin/perl -w

#
# 25-Nov-09 Display current status and % complete
# 13-Mar-13 Allow script to wait if status is commit pending, and show child engine status
# 28-Jun-13 Change killduplicates options (-k value or -K)
#           INDEX_INITIALIZING (-35) is now considered an active state (ie not an error)
# 20-Aug-13 Allow DREREPLACE to be specified - contents in a file which is read and POSTed
#           Corrected usage information - If posting always use a suffix of NOOP
# 07-Oct-13 Allow priority to be specified
#

use strict;
use warnings;

use Getopt::Std;
use LWP::UserAgent;
use File::Spec::Functions qw(rel2abs);

my $failed = 0;

BEGIN {
    $failed = 0;
};

END {
    print "\nFailed: $failed\n" if $failed > 0;
    $? = 1 if $failed > 0;
};

use constant DEFAULT_HOST => '127.0.0.1';
use constant DEFAULT_PORTQUERY => 14000;
use constant DEFAULT_PAUSE => 05;
use constant DEFAULT_TIMEOUT => 15;

my $ECHO_RESPONSE = 0;
my $ECHO_URL = 0;

use constant ACTION_ADD => 0;
use constant ACTION_REPLACE => 1;

use constant INDEX_PROCESSING                 =>   0;
use constant INDEX_FINISHED                   =>  -1;
use constant INDEX_OUT_OF_DISK                =>  -2;
use constant INDEX_FILE_NOT_FOUND             =>  -3;
use constant INDEX_DATABASE_NOT_FOUND         =>  -4;
use constant INDEX_BAD_PARAMETER              =>  -5;
use constant INDEX_DATABASE_EXISTS            =>  -6;
use constant INDEX_QUEUED                     =>  -7;
use constant INDEX_UNAVAILABLE                =>  -8;
use constant INDEX_OUTOFMEMORY                =>  -9;
use constant INDEX_INTERRUPTED                =>  -10;
use constant INDEX_XMLNOTWELLFORMED           =>  -11;
use constant INDEX_RETRYING                   =>  -12;
use constant INDEX_BACKUP_IN_PROGRESS         =>  -13;
use constant INDEX_MAX_INDEX_SIZE_EXCEEDED    =>  -14;
use constant INDEX_MAX_NUM_DOCS_EXCEEDED      =>  -15;
use constant INDEX_PAUSED                     =>  -16;
use constant INDEX_RESTARTED                  =>  -17;
use constant INDEX_CANCELLED                  =>  -18;
use constant INDEX_OUT_OF_FILE_DESCRIPTORS    =>  -19;
use constant INDEX_LANGUAGETYPE_NOT_FOUND     =>  -20;
use constant INDEX_SECURITYTYPE_NOT_FOUND     =>  -21;
use constant INDEX_UNSPECIFIED_PROBLEM        =>  -22;  # Returned by a DIH to indicate that its children returned irreconcilably different statuses
use constant INDEX_BADLY_FORMATTED_REQUEST    =>  -23;
use constant INDEX_INVALID_INDEX_CODE         =>  -24;
use constant INDEX_TO_BE_QUEUED               =>  -25;  # Returned by a DIH to indicate an index command that is to be sent to the DREs
use constant INDEX_NO_DREENDDATA_FOUND        =>  -26;  # The DREADDDATA did not contain a #DREENDDATA at the end
use constant INDEX_MAX_RETRIES_EXCEEDED       =>  -27;  # The command has failed to be accepted by the child engine more than the configured number of times
use constant INDEX_INVALID_INDEXID            =>  -28;  # The engine has no knowledge of the index ID 
use constant INDEX_JOB_REDISTRIBUTED          =>  -29;  # This command was redistributed to siblings as this engine was either unavailable or not accepting index jobs 
use constant INDEX_DATABASE_NAME_TOO_LONG     =>  -30;  # The database name is too long
use constant INDEX_IGNORED_IDMATCH            =>  -31;  # The command was ignored as its id has already been seen and processed
use constant INDEX_CONFIGURED_LIMIT_EXCEEDED  =>  -32;  # A user-configured limit on the index size has been exceeded
use constant INDEX_MAX_DATABASES_EXCEEDED     =>  -33;  # Cannot create a new database as we have reached the limit
use constant INDEX_PENDING_COMMIT             =>  -34;  # Index job has been finished but has not yet been committed to disk
use constant INDEX_INITIALIZING               =>  -35;  # Initial state for the DIH
use constant INDEX_READING_IDX                =>  -36;  # State for the DIH as, unlike the DRE, it reads the IDX when creating the index queue structure before processing it
use constant INDEX_GENERIC_FAIL               =>  -37;  # Index job failed for some reason other than those listed above (or the reason could not be determined)
use constant INDEX_REMOTE_PROCESSING          =>  -38;  # Index job is being processed in a remote engine

sub fail($;$)
{
    my ($message, $quiet) = @_;
    
    $quiet = 0 unless defined $quiet;
    
    print "FAIL: $message\n" unless $quiet;
    $failed ++;
}

sub getActionName($)
{
    my ($action)  = @_;
    
    return 'ADD' if $action == ACTION_ADD;
    return 'REPLACE' if $action == ACTION_REPLACE;
    
    return "Unknown action $action";
}

sub info($)
{
    my ($message) = @_;
    
    print "INFO: $message\n";
}

sub getURL($$)
{
  my ($url, $timeout) = @_;
  my $result = '';

  my $ua = LWP::UserAgent->new;
  $ua->agent("Mozilla/8.0"); # pretend we are very capable browser
  $ua->timeout($timeout);

  info("URL: $url") if $ECHO_URL;

  my $req = HTTP::Request->new(GET => $url);

  my $res = $ua->request($req);

  if ($res->is_success)
  {
    $result = $res->content;
    
    if ($ECHO_RESPONSE)
    {
      # Make the XML readable - Insert a line break between '>' and '<'
      my $readable = join(">\n<", split(/\>\</, $result));
      info("Response\n$readable\n");
    }
  }
  else
  {
    fail("HTTP Error: " . $res->message);
  }

  return $result;
}

sub postURL($$$)
{
  my ($url, $content, $timeout) = @_;
  my $result = '';

  my $ua = LWP::UserAgent->new;
  $ua->agent("Mozilla/8.0"); # pretend we are very capable browser
  $ua->timeout($timeout);

  info("URL '$url'") if $ECHO_URL;
  info("Content:\n\n$content\n") if $ECHO_URL;

  my $req = HTTP::Request->new(POST => $url);
  
  $req->content($content);

  my $res = $ua->request($req);

  if ($res->is_success)
  {
    $result = $res->content;
    
    if ($ECHO_RESPONSE)
    {
      # Make the XML readable - Insert a line break between '>' and '<'
      my $readable = join(">\n<", split(/\>\</, $result));

      info("Response:\n$readable\n");
    }
  }
  else
  {
    fail("HTTP Error: " . $res->message);
  }

  return $result;
}

sub getIndexID($)
{
  my ($result) = @_;
  
  return $1 if defined($result) && ($result =~ m/INDEXID=(\d+)/);
  
  fail("Index ID was not returned");
  if (defined $result)
  {
      print "---------\n";
      print "$result\n" ;
      print "---------\n";
  }
  
  return -1;
}

sub getIndexAction($$)
{
  my ($url, $timeout) = @_;

  my $result = getURL($url, $timeout);

  return getIndexID($result);
}

sub postIndexAction($$$)
{
  my ($url, $content, $timeout) = @_;

  my $result = postURL($url, $content, $timeout);

  return getIndexID($result);
}

sub isFinished($$)
{
    my ($status, $waitPendingCommit) = @_;
    
    return 1 if  INDEX_FINISHED       == $status;
    return 1 if (INDEX_PENDING_COMMIT == $status) && !$waitPendingCommit;
    
    return 0;
}

sub isActive($$)
{
    my ($status, $waitPendingCommit) = @_;
    
    return 1 if  INDEX_INITIALIZING   == $status;
    return 1 if  INDEX_READING_IDX    == $status;
    return 1 if  INDEX_PROCESSING     == $status;
    return 1 if  INDEX_QUEUED         == $status;
    return 1 if  INDEX_TO_BE_QUEUED   == $status;
    return 1 if (INDEX_PENDING_COMMIT == $status) && $waitPendingCommit;
    
    return 0;
}

sub waitForIndexAction($$$$$$$)
{
  my ($host, $portQuery, $id, $queryChildEngines, $waitPendingCommit, $timeout, $pause) = @_;
  my $rc = 0;

  return $rc if $id <= 0;
  
  my $url = "http://$host:$portQuery/?Action=indexergetstatus&index=$id";
  
  $url .= "&childdetails=true" if $queryChildEngines;
  
  info("Waiting for index request $id to complete");
  print "\n";

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
      fail("Unable to get status for index request $id");
      last;
    }
    
    $description = $1 if $result =~ m/<description>(.*?)<\/description>/i;
    
    if ($result =~ m/<docidrange>(\d+)-(\d+)<\/docidrange>/i)
    {
      $docIdFrom = $1;
      $docIdTo = $2;
    }
	
	$duration = $1   if $result =~ m/<duration_secs>(\d+)<\/duration_secs>/i;
	$percentage = $1 if $result =~ m/<percentage_processed>(\d+)<\/percentage_processed>/i;
	$processed = $1  if $result =~ m/<documents_processed>(\d+)<\/documents_processed>/i;
	$deleted = $1    if $result =~ m/<documents_deleted>(\d+)<\/documents_deleted>/i;

	my $info = "ID: $id - $description ($status)";
	$info .= " - $duration seconds ($percentage%)" if ($duration > 0) || ($percentage > 0);
	if (($processed > 0) || ($deleted > 0))
	{
		$info .= " processed: $processed" if $processed > 0;
		$info .= " deleted: $deleted" if $deleted > 0;
		if ($docIdFrom > 0)
		{
		  $info .= " (";
		  $info .= "$docIdFrom" if $docIdTo == $docIdFrom;
		  $info .= "$docIdFrom .. $docIdTo" if $docIdTo != $docIdFrom;
		  $info .= ")";
		}
	}
	info($info);
    
    if ($queryChildEngines)
    {
        my $first = 1;
        while ($result =~ m/<childstatus>(.*?)<\/childstatus>/gi)
        {
            my $child = $1;

            my $engineid;
            my $indexid = '';
            my $status = '';
            my $description = '';
            my $percentage = '';

            $engineid    = $1 if $child =~ m/<engineid>(\d+)<\/engineid>/i;
            $indexid     = $1 if $child =~ m/<indexid>(\d+)<\/indexid>/i;
            $percentage  = $1 if $child =~ m/<percentage_processed>(\d+)<\/percentage_processed>/i;
            $status      = $1 if $child =~ m/<status>(-{0,1}\d+)<\/status>/i;
            $description = $1 if $child =~ m/<description>(.*?)<\/description>/i;

            my $info = "   Engine: $engineid ID: $indexid - $description ($status)";
            $info .= " - ($percentage%)" if $percentage > 0;
            print "\n" if $first;
            info($info);
            $first = 0;
        }
        print "\n" unless $first;
    }
	
    if (isFinished($status, $waitPendingCommit))
    {
      $rc = 1;
      last;
    }
    
    if (!isActive($status, $waitPendingCommit))
    {
      fail("Status is $status - $description");
      last;
    }

    sleep($pause);
  }
  
  return $rc;
}

sub slurp($)
{
    my ($file) = @_;
    
    my $fh;
    
    return undef unless open($fh, "<", $file);
    
    local $/ = undef;
    my $content = <$fh>;
    
    close($fh);
    
    return $content;
}

sub addFile($$$$$$$$$$$$$$$$$)
{
  my ($host, $portQuery, $portIndex, $action, $post, $dreEndDataSuffix, $database, $file, $priority, $killDuplicates, $queryChildEngines, $wait, $waitPendingCommit, $delete, $timeout, $pause, $checkFileExistence) = @_;

  # Get the absolute path of the file, since IDOL needs this
  $file = rel2abs($file);
  
  if ($checkFileExistence)
  {
    unless (-e $file)
    {
      fail("File '$file' does not exist");
      return 0;
    }
  }

  my $id;
  
  if ($action == ACTION_ADD)
  {
    unless ($post)
    {
      my $url = "http://$host:$portIndex/DREADD?$file";
      $url .= "&Priority=$priority" if defined $priority;
      $url .= "&KillDuplicates=$killDuplicates" if defined $killDuplicates;
      $url .= "&DELETE" if $delete;
      $url .= "&DREDbName=$database" if defined $database;
      
      $id = getIndexAction($url, $timeout);
    }
    else
    {
      my $url = "http://$host:$portIndex/DREADDDATA?";
      $url .= "&Priority=$priority" if defined $priority;
      $url .= "&KillDuplicates=$killDuplicates" if defined $killDuplicates;
      $url .= "&DREDbName=$database" if defined $database;
      
      my $content = slurp($file);
      
      unless (defined $content)
      {
        fail("Unable to read contents of '$file'");
        return 0;
      }
      
      $content .= "\n#DREENDDATA$dreEndDataSuffix\n\n" if defined $dreEndDataSuffix;
      
      $id = postIndexAction($url, $content, $timeout);
    }
  }
  elsif ($action == ACTION_REPLACE)
  {
    if ($post)
    {
      my $url = "http://$host:$portIndex/DREREPLACE?";
      $url .= "&Priority=$priority" if defined $priority;
      $url .= "&DREDbName=$database" if defined $database;
      
      my $content = slurp($file);
      
      unless (defined $content)
      {
        fail("Unable to read contents of '$file'");
        return 0;
      }
      
      $content .= "\n#DREENDDATA$dreEndDataSuffix\n\n" if defined $dreEndDataSuffix;
      
      $id = postIndexAction($url, $content, $timeout);
    }
    else
    {
        fail("DREREPLACE must be posted");
        return 0;
    }
  }
  else
  {
    fail("Unknown action '$action'");
    return 0;
  }
  
  return 0 unless defined $id;
  return 0 if -1 == $id;
  
  info("File: $file (ID: $id)");
  print "\n";
  
  return 1 unless $wait;
  
  return waitForIndexAction($host, $portQuery, $id, $queryChildEngines, $waitPendingCommit, $timeout, $pause);
}

sub syncDatabase($$$$$$$$)
{
  my ($host, $portQuery, $portIndex, $queryChildEngines, $wait, $waitPendingCommit, $timeout, $pause) = @_;
  
  my $url = "http://$host:$portIndex/DRESYNC?";

  my $id = getIndexAction($url, $timeout);

  return 0 if -1 == $id;
  
  info("Forcing an index sync (ID: $id)");
  print "\n";
  
  return waitForIndexAction($host, $portQuery, $id, $queryChildEngines, $waitPendingCommit, $timeout, $pause) if $wait;
  
  return 1;
}
my %Options;

if (!getopts('cd:e:h:i:k:Knop:Pq:rRst:uwy:x', \%Options) || (($#ARGV + 1) <= 0))
{
  print "Usage: perl dreadd.pl [-c] [-d database] [-e suffix] [-h host] [-i port] [-k value | -K] [-n] [-o]\n";
  print "                      [-p seconds] [-P] [-q port] [-r] [-R] [-s] [-t seconds] [-u] [-w] [-y priority] [-x] File ...\n";
  print "\n";
  print "       -c          - Query child engines\n";
  print "       -d database - Database to add the file to, if it does not explicitly specify the database\n";
  print "       -e suffix   - #DREENDDATA suffix if posting (Default: NOOP)\n";
  print "       -h host     - DRE host to use (Default: " . DEFAULT_HOST . ")\n";
  print "       -i port     - DRE index port to use (Default: query port + 1 )\n";
  print "       -k value    - Kill duplicates value\n";
  print "       -K          - Do not specify kill duplicates value\n";
  print "       -n          - Do not wait for index request to complete\n";
  print "       -o          - Do not check file existence\n";
  print "       -p seconds  - Pause between indexergetstatus requests (Default: " . DEFAULT_PAUSE . ")\n";
  print "       -P          - POST data (use DREADDDATA if adding)\n";
  print "       -q port     - DRE query port to use (Default: " . DEFAULT_PORTQUERY . ")\n";
  print "       -r          - Echo response\n";
  print "       -R          - Invoke DREEPLACE\n";
  print "       -s          - Perform DRESYNC if at least one file added successfully\n";
  print "       -t seconds  - HTTP timeout (Default: " . DEFAULT_TIMEOUT . ")\n";
  print "       -u          - Echo URL\n";
  print "       -w          - Wait if pending commit\n";
  print "       -y priority - Priority to be used (0..100)\n";
  print "       -x          - Delete file after processing\n";
  print "\n";
  print "       File        - IDX files to add to IDOL via DREADD indexing action\n";
  exit;
}

my $action = ACTION_ADD;
my $post = 0;
my $database;
my $host = DEFAULT_HOST;
my $portQuery = DEFAULT_PORTQUERY;
my $portIndex = DEFAULT_PORTQUERY + 1;
my $timeout = DEFAULT_TIMEOUT;
my $pause = DEFAULT_PAUSE;
my $sync = 0;
my $wait = 1;
my $success = 0;
my $delete = 0;
my $waitPendingCommit = 0;
my $queryChildEngines = 0;
my $killDuplicates = 'REFERENCE';
my $dreEndDataSuffix;
my $checkFileExistence = 1;
my $priority;

# Allow environment variables to override static defaults
$action = $ENV{'DREADD_ACTION'} if defined($ENV{'DREADD_ACTION'});
$post = $ENV{'DREADD_POST'} if defined($ENV{'DREADD_POST'});
$queryChildEngines = $ENV{'DREADD_QUERY_CHILD_ENGINES'} if defined($ENV{'DREADD_QUERY_CHILD_ENGINES'});
$database = $ENV{'DREADD_DATABASE'} if defined($ENV{'DREADD_DATABASE'});
$host = $ENV{'DREADD_HOST'} if defined($ENV{'DREADD_HOST'});
$portQuery = $ENV{'DREADD_PORT_QUERY'} if defined($ENV{'DREADD_PORT_QUERY'});
$portIndex = $portQuery + 1;
$portIndex = $ENV{'DREADD_PORT_INDEX'} if defined($ENV{'DREADD_PORT_INDEX'});
$pause = $ENV{'DREADD_PAUSE'} if defined($ENV{'DREADD_PAUSE'});
$timeout = $ENV{'DREADD_TIMEOUT'} if defined($ENV{'DREADD_TIMEOUT'});
$sync = $ENV{'DREADD_SYNC'} if defined($ENV{'DREADD_SYNC'});
$wait = $ENV{'DREADD_WAIT'} if defined($ENV{'DREADD_WAIT'});
$checkFileExistence = $ENV{'DREADD_CHECK_FILE_EXISTENCE'} if defined($ENV{'DREADD_CHECK_FILE_EXISTENCE'});
$waitPendingCommit = $ENV{'DREADD_WAIT_PENDING_COMMIT'} if defined($ENV{'DREADD_WAIT_PENDING_COMMIT'});
$delete = $ENV{'DREADD_DELETE'} if defined($ENV{'DREADD_DELETE'});
$ECHO_URL = $ENV{'DREADD_ECHO_URL'} if defined($ENV{'DREADD_ECHO_URL'});
$ECHO_RESPONSE = $ENV{'DREADD_ECHO_RESPONSE'} if defined($ENV{'DREADD_ECHO_RESPONSE'});
$killDuplicates = $ENV{'DREADD_KILLDUPLICATES'} if defined($ENV{'DREADD_KILLDUPLICATES'});
$dreEndDataSuffix = $ENV{'DREADD_DREENDDATA_SUFFIX'} if defined($ENV{'DREADD_DREENDDATA_SUFFIX'});

# Allow command line to override defaults
$queryChildEngines = 1 if defined($Options{'c'});
$database = $Options{'d'} if defined($Options{'d'});
$dreEndDataSuffix = $Options{'e'} if defined($Options{'e'});
$host = $Options{'h'} if defined($Options{'h'});
$portQuery = $Options{'q'} if defined($Options{'q'}); # NOTE: Set before index port
$portIndex = $portQuery + 1;
$portIndex = $Options{'i'} if defined($Options{'i'});
$killDuplicates = $Options{'k'} if defined($Options{'k'});
undef $killDuplicates if defined($Options{'K'});
$wait = 0 if defined($Options{'n'});
$checkFileExistence = 0 if defined($Options{'o'});
$pause = $Options{'p'} if defined($Options{'p'});
$post = 1 if defined($Options{'P'});
$ECHO_RESPONSE = $Options{'r'} if defined($Options{'r'});
$action = ACTION_REPLACE if defined($Options{'R'});
$sync = $Options{'s'} if defined($Options{'s'});
$timeout = $Options{'t'} if defined($Options{'t'});
$ECHO_URL = $Options{'u'} if defined($Options{'u'});
$waitPendingCommit = 1 if defined($Options{'w'});
$priority = $Options{'y'} if defined($Options{'y'});
$delete = $Options{'x'} if defined($Options{'x'});

$waitPendingCommit = 0 if $sync;
$post = 1 if $action == ACTION_REPLACE;
$dreEndDataSuffix = 'NOOP' if !defined($dreEndDataSuffix) && $post;

print "\n";
print "DRE Indexing Utility\n";
print "\n";
print "Host:                 $host\n" if defined($host);
print "Port Query:           $portQuery\n" if defined($portQuery);
print "Port Index:           $portIndex\n" if defined($portIndex);
print "Database:             $database\n" if defined($database);
print "Action:               " . getActionName($action) . "\n" if defined($action);
print "POST:                 $post\n" if defined($post);
print "#DREENDDATA Suffix:   $dreEndDataSuffix\n" if defined($dreEndDataSuffix);
print "Check File Existence: $checkFileExistence\n" if defined $checkFileExistence;
print "Priority:             $priority\n" if defined $priority;
print "Kill Duplicates:      $killDuplicates\n" if defined $killDuplicates;
print "Timeout:              $timeout\n" if defined($timeout);
print "Pause:                $pause\n" if defined($pause);
print "Sync:                 $sync\n" if defined($sync);
print "Query Child Engines:  $queryChildEngines\n" if defined($queryChildEngines);
print "Wait:                 $wait\n" if defined($wait);
print "Wait Pending Commit:  $waitPendingCommit\n" if defined($waitPendingCommit);
print "Delete:               $delete\n" if defined($delete);
print "\n";

foreach my $file (@ARGV)
{
  $success = 1 if addFile($host, $portQuery, $portIndex, $action, $post, $dreEndDataSuffix, $database, $file, $priority, $killDuplicates, $queryChildEngines, $wait, $waitPendingCommit, $delete, $timeout, $pause, $checkFileExistence);
}

if ($sync && $success)
{
  # Force a sync of the database
  syncDatabase($host, $portQuery, $portIndex, $queryChildEngines, $wait, $waitPendingCommit, $timeout, $pause);
}
