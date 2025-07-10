# https://perldoc.perl.org/perlmod#Perl-Modules
# package Some::Module;  # assumes Some/Module.pm
package common;  # assumes common.pm
# use v5.36;

# Get the import method from Exporter to export functions and
# variables
# use Exporter 5.57 'import';
use Exporter 'import';
use Time::HiRes qw( time );
use POSIX qw/strftime/;

# use DateTime;

# set the version for version checking
our $VERSION = '0.02';

# Functions and variables which are exported by default
# our @EXPORT      = qw(func1 func2);
our @EXPORT = qw(read_fileItem formatedNow number2nameBook addCountryArea removeNonDigits doExecLog);

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

my %cfgHashs;
my $execLogFilePathName;
my $country; # e.g 0049
my $areaCode; # e.g. 089 for Munich
my $pkgName;
my $varFilePath;
my $cfgFilePathName;

# make all your functions, whether exported or not;
# remember to put something interesting in the {} stubs
# sub func1      { ... }


sub doExecLog {
  my $level=shift();
  if ($level =~ /^\d$/) {
    if ( $level > $cfgHashs{"LOGLEVEL"}) {
      print "Skip due to LogLevel $level ? $cfgHashs{'LOGLEVEL'} \n";
      return; # msg only if LOGLEVEL is higer
      }
    }
  else {
    unshift(@_, $level);
    $level=3;
    }  
  open(my $fh, '>>', $execLogFilePathName) or die "Could not open file '$execLogFilePathName' $!";
  my $spanStart="";
  my $spanEnd="";
  if ( $level lt 2 ) { # Error
    $spanStart="<span style=\"color:red;\">";
    $spanEnd="</span>"; 
    }
  print $fh strftime("%F %T: ", localtime time) . $spanStart . "@_" . $spanEnd . "\n";
  close $fh;
  }


# Search a file (with lines like 'key=value') for a list of keys
# In no keys given, then read all!
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
      (my $name, my $item) = split("=", $_, 2);
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
sub formatedNow { # including Milliseconds
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


sub removeNonDigits {
  my ( $number ) = @_;
  $number =~ s/[ \/()-]+//g; # e.g. (089) 234-123 ==> 089234123
  $number =~ s/[^\x00-\x7F]//g; # Entferne alle Zeichen außerhalb des ASCII-Bereich, z.B. – (EN DASH, E2 80 93) 
  $number =~ s/#$//; # remove trailing #, which FritzBox is sending
  return $number;
  }



# Nummer aus Telefonbuch (oder gewählte Nummer) um Vorwahlen ergänzen
sub addCountryArea {
  my ( $number0 ) = @_;
  $number0 =~ s/^\+/$vaz/; # e.g. +49 ==> 0049
  $number0 = removeNonDigits($number0);
  if ($number0 =~ /^\*\*.*/ ) { # Number begins with *: internal extension number like **621
    return $number0;
    }
  # Eigene Orts-Vorwahl ergänzen, wenn mit 1...9 beginnend, d.h. nicht mit 0 oder *
  if ($number0 =~ /^[1-9]/ ) { # starting with digit 1..9
    $number0 = "$areaCode$number0"; # add own area code
    }
  if ($number0 =~ /^$vaz.*/ ) { # starting with international access code (e.g. 00): o.k.
    return $number0;
    }  
  if ($cfgHashs{NUMPLAN} == 0) {
    # print "offener Nummernplan\n"; # Deutschland, Österreich
    $number0 =~ s/^0/$country/; # if starting with 0 from area code: remove that and add now country code like 0049
    } 
  else {
    # print "geschlossener Nummernplan\n"; # Schweiz
    $number0 = $country . $number0; # add now country code like 0041
    }
  return "$number0";
  }


# this one isn't always exported, but could be called directly
# as Some::Module::func3()
# sub func3      { ... }

# END { ... }       # module clean-up code here (global destructor)
my @pathItems=split("/", File::Spec->rel2abs( $0 )); # /var/packages/callmonitor/target/callmonitor.pl
$pkgName=$pathItems[3];
print "common.pm pkgName='$pkgName'\n";
$varFilePath="/var/packages/$pkgName/var";
$cfgFilePathName="$varFilePath/config";
%cfgHashs=read_fileItem "$cfgFilePathName"; # read all items
$vaz = $cfgHashs{VAZintl}; # e.g. 00 in western Europe, 011 in northern America
$country = $cfgHashs{COUNTRYCODE}; # e.g. 0049 for Germany
$country =~ s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
$areaCode=$cfgHashs{AREACODE}; # e.g. 089 for Munich
$areaCode =~ s/^\s*(.*?)\s*$/$1/; # trim

$execLogFilePathName="$varFilePath/execLog";


1;  # don't forget to return a true value from the file
