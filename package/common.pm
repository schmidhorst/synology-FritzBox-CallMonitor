# https://perldoc.perl.org/perlmod#Perl-Modules
# package Some::Module;  # assumes Some/Module.pm
package common;  # assumes common.pm
# use v5.36;

# Get the import method from Exporter to export functions and
# variables
# use Exporter 5.57 'import';
use Exporter 'import';
use Time::HiRes qw( time );
# use DateTime;

# set the version for version checking
our $VERSION = '0.01';

# Functions and variables which are exported by default
# our @EXPORT      = qw(func1 func2);
our @EXPORT      = qw(read_fileItem formatedNow);

# Functions and variables which can be optionally exported
# our @EXPORT_OK   = qw($Var1 %Hashit func3);

# exported package globals go here
# our $Var1    = '';
# our %Hashit  = ();
# our %myhashs = ();

# non-exported package globals go here
# (they are still accessible as $Some::Module::stuff)
# our @more    = ();
# our $stuff   = '';

# file-private lexicals go here, before any functions which use them
# my $priv_var    = '';
# my %secret_hash = ();

# here's a file-private function as a closure,
# callable as $priv_func->();
# my $priv_func = sub {
#    ...
# };


# make all your functions, whether exported or not;
# remember to put something interesting in the {} stubs
# sub func1      { ... }
# Search a file (with lines like 'key=value') for a list of keys
sub read_fileItem{
  local $filePathName = shift; # 1st Parameter: File name
  my $listSize= 1 + $#_;
  local @searchedItems = @_; # further parameters: keys of the items to extract
  # print "searching for: @searchedItems\n";
  my %myhashs;
  if (! -r $filePathName ) {
    print formatedNow() . "common.pm Error: read_fileItem() File (1st param) $filePathName does not exist or is not readable\n";
    return;
    }
  print formatedNow() . "common.pm read_fileItem File (1st param)=$filePathName, further $listSize parameters\n";
  open (FILE, "$filePathName");
  while (<FILE>) {
    chomp;
    if ((substr($_,0,1) ne "#" ) && ($_ ne "")) {
      (my $name, my $item) = split("=");
      $name=~ s/^\s+|\s+$//g; # trim
      $item=~ s/^\s+|\s+$//g; #trim
      $item =~ s/^"//;
      $item =~ s/"$//g;
      # print "from File: name='$name', item='$item'\n";
      # my @matches = grep { /$name/ } @searchedItems;
      # note that grep returns a list, so $matched needs to be in brackets to get the 
      # actual value, otherwise $matched will just contain the number of matches
      if ($listSize==0) {
        $myhashs{$name}=$item; # add as new item to the hash
        }
      elsif (my ($matched) = grep $_ eq $name, @searchedItems) {
        # print "found it: $matched\n"; # that os the key
        # print "Match found: $name with $item\n";
        $myhashs{$name}=$item; # add as new item to the hash
        }
      }
    }
  close (FILE);
  # my $hash_count = keys %myhashs;
  # print "$hash_count items found\n";
  return %myhashs;
  }

# https://stackoverflow.com/questions/37443718/how-can-i-display-the-current-date-and-time-including-microseconds
sub formatedNow {
  my $epoch = time();
  # my $microsecs = ($epoch - int($epoch)) *1e6;
  my $millisec = ($epoch - int($epoch)) *1e3;
  my ($Sekunde, $Minute, $Stunde, $Tag, $Monat, $Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime($epoch);
  $Monat+=1;
  # $Jahrestag+=1;
  $Monat = $Monat < 10 ? $Monat = "0".$Monat : $Monat;
  $Tag = $Tag < 10 ? $Tag = "0".$Tag : $Tag;
  $Stunde = $Stunde < 10 ? $Stunde = "0".$Stunde : $Stunde;
  $Minute = $Minute < 10 ? $Minute = "0".$Minute : $Minute;
  $Sekunde = $Sekunde < 10 ? $Sekunde = "0".$Sekunde : $Sekunde;
  $Jahr+=1900;
  return "$Jahr-$Monat-$Tag $Stunde:$Minute:$Sekunde" . "." . sprintf("%03.0f", $millisec) . " ";
  }

# this one isn't always exported, but could be called directly
# as Some::Module::func3()
# sub func3      { ... }

# END { ... }       # module clean-up code here (global destructor)

1;  # don't forget to return a true value from the file
