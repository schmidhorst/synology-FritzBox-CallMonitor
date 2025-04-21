#!/usr/bin/perl

#Version 0.?
#written by eiGelbGeek 2017
#Version 0.?, muliple code rewritten using arrays
# Horst Schmid 2025

# to do:
# read phonebooks from FritzBox directly
use utf8;
# use open ':encoding(utf8)';
use strict;
use warnings;
use File::Basename;
use File::Spec;
use warnings 'all';
# use Env;
use Encode;
use POSIX qw/strftime/;
# https://stackoverflow.com/questions/8733131/getting-stdout-stderr-and-response-code-from-external-nix-command-in-perl

# include-current-directory to @INC:
# https://stackoverflow.com/questions/46549671/doesnt-perl-include-current-directory-in-inc-by-default
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname( abs_path( $0 ) );
use common; # use module common.pm with sub read_fileItem

my %telBook = (); # Telefonbuch der vollständigen Nummern, 
    # key=bereinigte Nummer, item=($name, $book, $number0 (OriginalFormat))
my %telBookWild = (); # Telefonbuch der WildcardNummern
# http://www.hidemail.de/blog/absoluten-pfad-herausfinden.shtml
my $scriptPath = File::Spec->rel2abs( $0 );
my $scriptDir = dirname( $scriptPath );
my $scriptFile = basename( $scriptPath );
# /var/packages/callmonitor/target/callmonitor.pl
# /volume1/@appstore/callmonitor/callmonitor.pl
my $NOTIFY_USERS='@users';
my $pkgName;
if ( length $ENV{SYNOPKG_PKGNAME}) {
  $pkgName=$ENV{SYNOPKG_PKGNAME}
  }
else {
  ($pkgName = $scriptFile) =~ s/\.[^.]+$//;
  }
my @pathItems=split("/", $scriptDir);
print "pkgName=$pkgName, pathItems[3]=$pathItems[3]\n";  
my $varFilePath="/var/packages/$pkgName/var";
my $cfgFilePathName="$varFilePath/config";
my $execLogFilePathName="$varFilePath/execLog";

my %cfgHashs;
my $dsmappname;

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


my $country;
my $areaCode;


sub processDuplBookEntry {
  my ( $number1, $number0, $name1, $book1, $name2, $book2, @others ) = @_;
  my $book = $book1;
  if ($name1 ne $name2) {
    my $msg="For number $number1 ($number0) we have different names: $name1 (Book $book1) and $name2 (Book $book2)";
    print "$msg\n";
    doExecLog(5, $msg);
    }
  if ($book1 ne $book2) {
    $book = "$book1, $book2";
    }
  elsif ($name1 eq $name2) {
    my $msg = "Number $number0 ($number1) for '$name1' found duplicate in book $book";
    print "$msg\n";
    doExecLog(5, $msg);
    }
  return ($name2, $book, $number0);
  }

sub addCountryArea {
  my ( $number0 ) = @_;
  $number0 =~ s/^\s*(.*?)\s*$/$1/; # trim
  $number0 =~ s/#$//; # remove trailing #, which FritzBox is sending
  $number0 =~ s/^\+/00/; # e.g. +49 ==> 0049
  $number0 =~ s/[ \/()-]+//g; # e.g. (089) 234-123 ==> 089234123
  $number0 =~ s/[^\x00-\x7F]//g; # Entferne alle Zeichen außerhalb des ASCII-Bereich, z.B. – (EN DASH, E2 80 93) 
  # Eigene Orts-Vorwahl ergänzen, wenn mit 1...9 beginnend, d.h. nicht mit 0 oder *
  if ($number0 =~ /^\*\*.*/ ) {
    return $number0;
    }
  if ($number0 =~ /^[1-9]/ ) {
    $number0 = "$areaCode$number0";
    }
  if ($number0 =~ /^00.*/ ) {
    return $number0;
    }  
  $number0 =~ s/^0//;
  return "$country$number0";
  }

# Insert number and Name to internal hash table
sub insertToTelBook {
  my ( $number0, $name, $book, @others ) = @_;
  my $number1 = addCountryArea($number0);
  $name =~ s/;/ /g; # Replace semcolon by space as semicolon is later our list separator
  # Eigene Landes-Vorwahl ergänzen, wenn nicht mit 00 beginnend???
  if ($number1 =~ /.*\*$/) { # with '*' at the end
    # print("WildCard: $number1 $name, book='$book' ");
    $number1 =~ s/\*/\.\*/; # replace trailing * bei regExp .*
    # print("$number1\n");
    my @ar=($name, $book, $number0);
    if (exists($telBookWild{$number1})) { # from another phone book
      my ($name2, $book2, $number02)=@{$telBookWild{$number1}};
      @ar=processDuplBookEntry($number1, $number0, $name2, $book2, $name, $book);
      }
    $telBookWild{$number1}=[@ar];
    }
  else { # normal number
    # print("Normal: $number $name $book\n");
    my @ar=($name, $book, $number0);
    if (exists($telBook{$number1})) { # from another phone book already available
      my ($name2, $book2, $num0)=@{$telBook{$number1}};
      @ar=processDuplBookEntry($number1, $number0, $name2, $book2, $name, $book);
      }
    $telBook{$number1} = [@ar];
    # https://stackoverflow.com/questions/5384825/perl-assigning-an-array-to-a-hash
    # $telBook{$number}=($name, $book);
    }
  }


#Simple Text-Telefonbuch-Datei (incl. Nebenstellennamen!?) einlesen:
sub read_txt_telBook {
  my ( $filePathName, $book, @others ) = @_;
  print "reading book '$book' ($filePathName) ...\n";
  open(IN, "<:encoding(UTF-8)", $filePathName) or do {
    my $err=$!;
    my $errMsg="Error to read phonebook $filePathName  ($book): $err";
    print "$errMsg";
    doExecLog(1, $errMsg);
    # msg2: "Fehler beim Lesen/Aktualisieren des Telefonbuchs {0}: {1}"
    system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg2", "$filePathName  ($book)", "$err");    
    return ();
    }; 
  while(<IN>){
    chomp;
    # s/\A\N{BOM}//;
    # print("1st:" . ord(substr($_,0,1))); # 239 ???
    s/^\s*(.*?)\s*$/$1/; # trim
    if (($_ ne '') && (substr($_, 0, 1) ne '#')) {
      # print "line='$_'\n";
      my @elements = split(":", $_, 2);
      my $number=$elements[0];
      # print "line='$_' => '$number':'$elements[1]'\n";
      insertToTelBook($number, $elements[1], $book);
      }
    }
  close(IN);
  }


sub read_cardDAV_telBook { # read one CardDAV telephone book (http or https)
  # https://stackoverflow.com/questions/53737369/how-to-execute-curl-command-from-a-perl-script
  # https://corion.net/curl2lwp.psgi
  use LWP::UserAgent;
  use IO::Socket::SSL;

  # curl "$src" -o "$vcf" -u "$user:$password" -H 'sec-fetch-dest: document' --compressed --insecure -H 'accept: text/vcard; charset=utf-8,text/html,application/xhtml+xml,application/xml;q=0.9'
  my ( $src, $user, $password, $bookName, @others ) = @_;
  # print("start of read_cardDAV_telBook, url=$src\n");
  my $vcard="";
  # use shell for http and https as encoding problem with LWP and module for SSL is missing !!!!
  print "https-Reading via shell curl charset=utf-8 ...\n";
  $vcard=`curl "$src" -u "$user:$password" -H 'sec-fetch-dest: document' --compressed --insecure -H 'accept: text/vcard; charset=utf-8,text/html,application/xhtml+xml,application/xml;q=0.9'`;
  my $exitCode=$?;
  print "curl exit code = $exitCode\n";
  #my $cmd="curl \"$src\" -u \"$user:$password\" -H 'sec-fetch-dest: document' --compressed --insecure -H 'accept: text/vcard; charset=utf-8,text/html,application/xhtml+xml,application/xml;q=0.9'";
  #my ($stdout, $stderr, $exitCode) = capture { system( $cmd ); };
  if ($exitCode != -1) { # -1 if command not found
    $exitCode= $exitCode >> 8; # return code from the command
    }
  # print "curl exitCode=$exitCode\n"; # always zero!??
  my $errMsg="";
  if ($exitCode != 0) {
    if ( $exitCode == 35 ) {
      $errMsg="curl error '$exitCode' from curl to read CardDAV telephone book from '$src': Seems to be an http port used for https!?\n";
      }
    else {
      $errMsg="curl error '$exitCode' to read CardDAV telephone book from '$src' as user '$user':\n\n$vcard\n";
      }
    print "$errMsg\n";
    doExecLog(1, $errMsg);
    # msg4="Fehler beim Lesen/Aktualisieren des CardDAV-Telefonbuchs {0} mit dem Account '{1}': {2}"
    system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg4", "$bookName ($src)", "$user", "$exitCode");    
    return;
    };
  $vcard=encode('utf-8', $vcard); # WideChar to utf-8, avoid "code points over 0xFF" warning
  if ( not($vcard =~ "^BEGIN:VCARD.*") ) { # possibly "The requested resource could not be found." with exitCode==0 
    $errMsg="CardDAV read error $bookName ($src): $vcard";
    print "$pkgName: $errMsg\n";
    doExecLog(1, $errMsg);
    # msg4="Fehler beim Lesen/Aktualisieren des CardDAV-Telefonbuchs {0} mit dem Account '{1}': {2}"
    system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg4", "$bookName ($src)", "$user", "$vcard");    
    return;
    }
  print("... curl CardDAV reading via shell curl done with success\n");
  # print "\n\n$vcard\n\n";
  $vcard =~ s/\r\n/\n/g; # \r\n ==> \n
  $vcard =~ s/\r/\n/g; # Macintosh \r should not occure in CardDAV
  # print "\n\n$vcard\n\n";
  # analyse Lines of VCARD-File:
  open my $fh, '<:encoding(UTF-8)', \$vcard; # 
  my $fullName="";
  my $name="";
  my @numbers=();
  while (<$fh>) {
    chomp;
    my $line=$_;
    # print "\nEvaluating $line\n";
    if ($line =~ /^FN:/) {
      $fullName=substr($line,3);        
      # print "FN $fullName\n";
      }
    elsif ($line =~ /^N:/) {
      $name=substr($line,2);        
      # print ("N $name \n");
      }
    elsif ($line =~ /^TEL/ ) {
      # print " TEL: $line \n";
      my($pre, $number) = split(/:/, $line);
      push(@numbers, $number);
      }      
    elsif ($line =~ /END:VCARD/ ) {
      if ($fullName ne "") {
        # print("Entry: $fullName\n");
        $name=$fullName;
        }
      elsif($name ne "") { # no FN, only N
        $name =~ s/^N://;
        $name =~ s/;//g;
        $name =~ s/^\s*(.*?)\s*$/$1/; # trim
        }
      if ($name ne "") { # normaly we should have a name!
        $name =~ s/\\//; # sometimes "\,"
        my $n = 1 + $#numbers; # n numbers for one Name
        # print(" $n numbers: $name book='$bookName'\n"); # warum fehlt erstes Zeichen???
        foreach (@numbers) {
          insertToTelBook($_, $name, $bookName); # make an Entry for each number
          }          
        $fullName="";
        $name="";
        @numbers=();
        }
      else {
        print("Error: Name missing for $numbers[0]\n");
        }  
      }
    } # while
  close $fh or die $!;  
  print("... CardDAV done\n");
  } # read_cardDAV_telBook


# read one FritzBox XML phone book:
sub read_xml_telBook { 
  no warnings;
  my $rn;
  # my $number;
  my @numbers=();
  my $is_phb;
  my $is_number;
  my $is_realName; 

  my ( $filePathName, $book, @others ) = @_;
  # https://www.linux-magazin.de/ausgaben/2005/08/datenfischer/2/
  # use XML::Simple; # not available
  # use XML::LibXML; # not available
  # use XML::LibXML; # not available
  use XML::Parser;
  # my $p = XML::Parser->new(Style => 'Debug');
  # my $p = XML::Parser->new(ProtocolEncoding => 'UTF-8'); # not working
  my $p = XML::Parser->new();
  my $book1=$book; # use the configured name for the phone book
  # if empty, then the book name found inside the file will be used
  print "parsing book='$book' ($filePathName)...\n";
  # $p->setEncoding('UTF-8'); # Syntax-Error
  $p->setHandlers(
    Start  => \&start,
    End  => \&handle_end,
    Char   => \&text
    );
  $p->parsefile($filePathName) or do {
    my $err=$!;
    my $errMsg="Error to read phonebook $filePathName  ($book): $err";
    print "$errMsg";
    doExecLog(1, $errMsg);
    # msg2: "Fehler beim Lesen/Aktualisieren des Telefonbuchs {0}: {1}"
    system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg2", "$filePathName  ($book)", "$err");    
    return ();
    };

  sub start { # of XML item
    my($p, $tag, %attrs) = @_;
    $is_phb = ($tag eq "phonebook");
    if ($is_phb) {
=pod
      print "start tag=$tag, attrs=";
      keys %attrs; # reset the internal iterator so a prior each() doesn't affect the loop
      while(my($k, $v) = each %attrs) { 
        print " $k=$v";
        }
      print "book1=$attrs{'name'}";
=cut
      if ($book eq "") { # overwrite configured book name by the exported name
        $book1=$attrs{"name"};
        }
      }
    $is_number = ($tag eq "number");
    $is_realName = ($tag eq "realName")
    } # sub start
 
  sub text { # text of xml item: If it's a name, cache it, it its a number: put it to hash table
    my($p, $text) = @_;
    chomp($text);
    $text=encode('utf-8', $text); ## with use utf8 still required???
    $text =~ s/^\s*(.*?)\s*$/$1/; # trim
    if ($text ne "") {
      # print("txt=$text, num=$is_number, rn=$is_realName\n");
      if ($is_realName) {
        $text =~ s/&amp;/&/g; # &amp; ==> & 
        # gibt es sonstiges zu decodieren?
        $rn=$text;
        }
      elsif ($is_number) {
        $text =~ s/^\s*(.*?)\s*$/$1/; # trim ( s* = multiple Whitespace )
        push(@numbers, $text);
        }
      }
    } # sub text

  sub handle_end { # end of an XML item
    my($p, $text) = @_;
    # print "END: $p, $text\n";
    if ($text eq "contact") { # all numbers and the name for one contact collected
      # 'contact' is the only item we need to process, all other ends are ignored
      if ($rn eq "") {
        my $msg="Error: No name for number $numbers[0]\n";
        print ("$msg");
        doExecLog(2, $msg);
        }
      elsif($#numbers == -1) {
        my $msg="Warning: No number for $rn\n";
        print "$msg";
        doExecLog(3, $msg);
        }
      else {
        # my $n = 1+$#numbers;
        # print(" $n numbers: $rn \n"); # warum fehlt erstes Zeichen???
        foreach (@numbers) {
          insertToTelBook($_, $rn, $book1); # make an Entry for each number
          }
        }
      $rn="";
      @numbers=();
      }    
    if ($text eq "phonebook") {
      # print "book name reset from '$book1' (from inside the XML) to '$book' (cofigured during installation)\n";
      $book1=$book;
      }
    } # handle_end
  } # sub read_xml_telBook


# Lookup the name for a given number in the hash tables
sub number2nameBook {
  # find the given Number either in $telBook{$number} or in $telBookWild{$key}
  my ($number) = @_;
  $number = addCountryArea($number);
  print "scanning for $number ...";
  # doExecLog(6, "number2nameBook(), cleaned number='$number'");
  if (exists($telBook{$number})) { # normal number
    my ($callerName, $bookName, $numberFormated)=@{$telBook{$number}};
    doExecLog(6, "number2nameBook(), cleaned number='$number' resolved to $callerName, $bookName");
    print "found!\n";
    return($callerName, $bookName, $numberFormated);
    }
  print "scanning wildCardBooks...";
  foreach my $key (keys %telBookWild) { # Find e.g. Entry "0032*:Belgium_" for 00326875676
    my $num3=$number; # 004989234*
    if ( $num3 =~ /$key/ ) {
      my $len=length($key)-2;
      # my $name=$telBookWild{$key} . substr($number, $len); # return e.g. Belgium_6875676
      my ($name, $book, $numberFormated)=@{$telBookWild{$key}};
      $name = $name . substr($num3, $len); # return e.g. Belgium_6875676
      doExecLog(4, "number2nameBook(), cleaned number='$number' resolved to $name from $book");
      return ($name, $book, $number) # [CallerName, BookName]
      }
    }
  doExecLog(4, "number2nameBook(), cleaned number='$number' not resolved");
  ## Übersetzung
  print " Number not found!";
  return ("Unbekannt", "", $number);
  }


my @ownLineNumbers;
my @SIP_ConID;          # $C[2] Von FB gemeldete ConnectionID für den Call
my @CCU_SysVars;


sub getLineNumberIdx {
  my ($ownLineNumber, $what) = @_;
  my @idx = grep { $ownLineNumbers[$_] eq $ownLineNumber } 0 .. $#ownLineNumbers;
  if ( $#idx == -1) {
    print "Error: unknown Line number $ownLineNumber ($what)! Check your SIP_Nummer-Configuration!\n";
    doExecLog(3, "unknown Line number $ownLineNumber ($what)! Check your SIP_Nummer-Configuration!");    
    return -1;
    }
  print "getLineNumberIdx() ok: $what $idx[0] $ownLineNumber\n";
  return $idx[0];
  }


# for further event (connect, disconnect) get the connectionID (from RING or CALL):
sub getConIdx {
  my ($conId, $what) = @_;
  my @idx = grep { $SIP_ConID[$_] eq $conId } 0 .. $#SIP_ConID;
  if ( $#idx == -1) {
    print "Error: unknown Connection ID $conId at $what!!\n";
    doExecLog(2, "unknown Connection ID $conId at $what!");    
    return -1;
    }
  # my $line=1 + $idx[0];
  # print "getConIdx() ok: what=$what idx=$idx[0] (Line #$line) ConID=$conId\n";
  return $idx[0];
  }


# FritzBox liefert z.B. 22 für Nebenstelle **622
sub expandNebenstelle {
  my ($ns0) = @_;
  if (length($ns0)==1) {
    $ns0="**$ns0"; # 1 ==> **1
    }
  else { # length() == 2
    $ns0="**6$ns0"; # 21 ==> **621
    }  
  if (exists($telBook{$ns0})) { # wenn im Telefonbuch vorhanden: Namen (z.B. "Flur") statt Nr (z.B. 11) verwenden
    my ($ns1, $book, @others)=@{$telBook{$ns0}}; # $name, $book, $number0 (OriginalFormat)
    $ns0=$ns1;
    }
  return $ns0; # e.g. 22 ==> **622 or "Home Office"
  }


##################### MAIN ##################
print  formatedNow() . basename( $scriptPath ) . " Die Datei $scriptFile liegt im Verzeichnis $scriptDir.\n";

# my $webServerPath = "/PFAD/BIS/ZUM/WEBSERVER";
my $webServerPath = "$scriptDir/ui";

my %tmpHash=read_fileItem dirname($scriptDir) . "/INFO", "dsmappname";
$dsmappname=$tmpHash{dsmappname}; # e.g. "SYNO.SDS._ThirdParty.App.callmonitor", required for synodsmnotify command

print "read_fileItem($cfgFilePathName)...\n";
%cfgHashs=read_fileItem "$cfgFilePathName"; # read all items
# $cfgHashs{CCU_PW} and $cfgHashs{DAV_PW} should be set to "*****" in the config file, real PW is in var/pw file (roor only access)
%tmpHash=read_fileItem "$varFilePath/pw";
%cfgHashs = (%cfgHashs, %tmpHash);

$country = $cfgHashs{COUNTRYCODE};
$country =~ s/^\s*(.*?)\s*$/$1/; # trim
$areaCode=$cfgHashs{AREACODE};
$areaCode =~ s/^\s*(.*?)\s*$/$1/; # trim

if ( ! exists $cfgHashs{IP_FRITZBOX} ) {
  die formatedNow() . basename( $scriptPath ) . " Error: Could not get IP address IP_FRITZBOX of FritzBox!\n"; 
  }
print "  IP_FRITZBOX=$cfgHashs{IP_FRITZBOX}\n";
print "  IP_CCU=$cfgHashs{IP_CCU}\n";

#Rufnummern der SIP-Accounts (Leitungen)
@ownLineNumbers = split(";", $cfgHashs{"SIPLINE_NUMBERS"});

# Umlaute und Sonderzeichen HTML Codiert eintragen:
use HTML::Entities; # bei UTF-8 nicht notwendig!?

my @lineNames = split(";", $cfgHashs{"SIPLINE_NAMES"});
for my $i (0 .. $#lineNames) {
  if (index($lineNames[$i], "&") == -1) { # seems to be not yet HTML encoded
    # besser: nach &xx; oder &xxx; oder &xxxx; suchen #######################
    $lineNames[$i]=encode_entities($lineNames[$i]); # ist dies bei UTF-8 noch notwendig?
    }
  }
  

#ISE-ID von Systemvariable für SIP Account (Belegt/Frei) für curl-Kommando z.B.
# system "curl 'http://'$IP_CCU'/config/xmlapi/statechange.cgi?ise_id='$SIP_IseID[0]'&new_value=1'";
# my @SIP_IseID  = qw($CCU_ISEIDS);
@CCU_SysVars = split(';', $cfgHashs{"CCU_SYSVARS"});
print "CCU_SysVar-Namen: $CCU_SysVars[0], $CCU_SysVars[1], $CCU_SysVars[2]\n";

# Alternativ-Kommando mit Namen statt ISE-ID (in BASH-Syntax):
# system "curl -u $CCU_USER:$CCU_PW -G --data-urlencode 'Status=dom.GetObject(\"'$CCU_SysVars[0]'\").State(0)' 'http://$IP_CCU:8181/test.exe'"

my @NebenstelleNr; # e.g. 21 for **621
my @NebenstelleNrName; # if Name defined the Name, else the number
my @zeilen;
use IO::Socket;
my $msgTbRead="";

if ($cfgHashs{"TELBOOK_TXT"} ne "") { # Attention: In bash -ne is numerical compare, in Perl ne is string compare!
  if (-e $cfgHashs{"TELBOOK_TXT"}) {  # Textfile
    &read_txt_telBook($cfgHashs{"TELBOOK_TXT"}, $cfgHashs{"BOOKNAME_TXT"});
    }
  else {
    print "File $cfgHashs{'TELBOOK_TXT'} is missing\n";
    }  
  }
else {
  print "No TELBOOK_TXT defined\n";
  }
my $telCnt0=keys %telBook;
print "TXT telCnt=$telCnt0\nGoing to read XML files...\n";
if ($#ARGV >= 0) {
  if ($ARGV[0] eq "restart") {
    $msgTbRead="Restarted! ";    
    }
  }
$msgTbRead="${msgTbRead}Read $telCnt0 entries from TEXT-Book";
my $cnt=0; #
my $idx=0;
while (1) { # Read the files with names TELBOOK_XML1, TELBOOK_XML2, ...
  $idx++;
  my $tb="TELBOOK_XML$idx";
  my $tbn="BOOKNAME_XML$idx";
  if (!exists($cfgHashs{$tb})) {
    print "no cfgHash with key $tb\n";
    last;
    }
  if ($cfgHashs{$tb} ne "") {
    if(-e $cfgHashs{$tb}) { # FritzBox XML file
      $cnt++;
      &read_xml_telBook($cfgHashs{$tb}, $cfgHashs{$tbn});
      }
    else {
      print "File $cfgHashs{$tb} is missing\n";
      }  
    }
  else {
    print "$tb is not defined\n";
    }  
  }
my $telCnt1 = keys(%telBook) - $telCnt0;
$msgTbRead="$msgTbRead, $telCnt1 entries from $cnt XML-Books";
my $telCnt2 = keys(%telBook);
# read the URLs TELBOOK_DAV1, TELBOOK_DAV2, ...:
my $user=$cfgHashs{'DAV_USER'}; # 'sHome'; # for CardDAV download
my $password=$cfgHashs{'DAV_PW'};
$cnt=0;
$idx=0;
while (1) {
  $idx++;
  my $tb="TELBOOK_DAV$idx";
  my $tbn="BOOKNAME_DAV$idx";
  if (!exists($cfgHashs{$tb})) {
    print "no cfgHash with key $tb\n";
    last;
    }
  if ($cfgHashs{$tb} ne "") {
    my $userX=$user;
    if (exists($cfgHashs{"DAV_USER$idx"})) {
      if ($cfgHashs{"DAV_USER$idx"} != "") {
        $userX=$cfgHashs{"DAV_USER$idx"};
        }
      }
    my $passwordX=$password;
    if (exists($cfgHashs{"DAV_PW$idx"})) {
      if ($cfgHashs{"DAV_PW$idx"} != "") {
        $passwordX=$cfgHashs{"DAV_PW$idx"};
        }
      }
    print("\ncalling read_cardDAV_telBook ${idx}: $cfgHashs{$tb} ...\n");
    $cnt++;
    read_cardDAV_telBook($cfgHashs{$tb}, $userX, $passwordX, $cfgHashs{$tbn});
    print("... read_cardDAV_telBook ${idx} done\n");
    }
  else {
    print "$tb is not defined\n";
    }  
  }

my $telCnt=keys %telBook;
my $telCnt3 = $telCnt - $telCnt2;
$msgTbRead="$msgTbRead, $telCnt3 entries from $cnt CardDAV-Books, total $telCnt entries";
doExecLog(4, $msgTbRead);
print "total telCnt=$telCnt\n";
# print("WildCard-Test 0035680798: " . number2nameBook("0032680798") . "\n");

=pod
print "All TelBook Entries:\n";
keys %telBook; # reset the internal iterator so a prior each() doesn't affect the loop
foreach my $number (keys %telBook) {
  my ($name, $b, $numberFormated)=@{$telBook{$number}};
  print "  $b: $number=$name\n";
  }
=cut

# $dsmappname is setup in INFO file, e.g. "SYNO.SDS._ThirdParty.App.callmonitor"
# $dsmappname needs to match the .url in ui/config. Otherwise synodsmnotify will not work
# app1:title01 and app1:msgX as 'preloadTexts' in ui/config
# title01, msg1 in Section [app1] in ui/texts/<lng>/strings with e.g placeholders {0}
# msg1="{0}"

=pod
# funktioniert nicht, zu kurz nach dem Start der App!!
print "Test-synodsmnotify Class='$dsmappname', target='$NOTIFY_USERS', title1:msg1='Test-Desktop-Message'\n";
my $msg="/usr/syno/bin/synodsmnotify -c $dsmappname $NOTIFY_USERS $pkgName:app1:title1 $pkgName:app1:msg1 Test-Desktop-Message";
print "$msg\n";
doExecLog(6, "$msg");
system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg1", "Test-Desktop-Message");
=cut

$SIG{TERM} = sub { die "Caught a sigterm, probably from start-stop-status.\n  $!" };

# zu Testzwecken kann mit Parametern aufgerufen werden:
while ($#ARGV > -1) {
  my $item = shift @ARGV;
  print "$item\n";
  if ( lc($item) eq "dump" ) {
    # print "$_ $telBook{$_}\n" for (keys %telBook);
    foreach my $key (keys %telBook) {
      my ($name, $book, $raw)= @{$telBook{$key}};
      print "$key ($raw) $book $name\n";
      }
    }
  elsif ( length($item) == 2) {
    my $ns = expandNebenstelle($item);
    print "$item => $ns\n";
    }
  elsif (( $item =~ /^\d+$/ ) or ($item =~ /^\*\*.*/)) {
    # print "Number $item: ";
    my ($externalName, $book, $numberFormated)=number2nameBook($item);
    print "$numberFormated $externalName ($book)\n";
    }
  else {
    print "wrong Parameter '$item', either 'dump', a pure interger number or no parameter are allowed!\n";
    }  
  }


#Open the web socket to listen on port 1012 of the FritzBox:
my $sock = new IO::Socket::INET (
  PeerAddr => $cfgHashs{IP_FRITZBOX},
  PeerPort => '1012',
  Proto => 'tcp'
  );
  die "Could not create socket: $! Is the call monitor activated via #96*5* in the FritzBox?\n" unless $sock;

# Arrays für die SIP-Accounts (konfigurierte Leitungen) 0, 1, 2, ...:
my @timestamps;         # $C[0]
my @what;               # $C[1] RING, CALL, CONNECT, DISCONNECT
my @SIP_INorOUT_Call;   # active call, IN=eingehend, OUT= ausgehend
my @externalNames;      # "Unknown" oder Name aus Telefonbuch
my @externalNumbers;    # $C[3] Anrufernummer
my @ownLineNumberNames;
my @phonebookNames;
print  formatedNow() . basename( $scriptPath ) . ": Waiting for calls ...\n";
doExecLog(5, "Waiting for calls ...");

while(<$sock>) { #warten auf aktiven Anruf#

  #Rückgabewerte des Internen Fritzbox Anrufmonitor
  # $C[0] = Datum
  # $C[1] = RING, CALL, CONNECT, DISCONNECT
  # $C[2] = ConnectionID 
  chomp;  # avoid \n on last field
  my @C = split(/;/);
  for my $i (0 .. $#C) {
    $C[$i] =~ s/\r$//;
    print "C[$i]='$C[$i]' ";
    }
  print "\n";  

  if ( $C[1] eq "RING") { # eingehender Anruf
    my $externalNumber=$C[3];
    my $ownLineNumber=$C[4]; # $C[4] = Angerufene-Nummer (eigene Line-Nummer)
    # $idxLine (LeitungsNr. 0, 1, 2) mittels der eigene Nummer $C[4] holen:
    # $C[5] e.g. "SIP0"
    my $idxLine = getLineNumberIdx($ownLineNumber, $C[1]); # scan @ownLineNumbers
    # $C[5] = SIP-Account
    #Prüfen ob Rufnummer im Telefonbuch vorhanden ist:
    my ($externalName, $book, $numberFormated)=number2nameBook($externalNumber);
    print "RING C[3]=$externalNumber ($numberFormated, $externalName) bei C[4]=Line=$C[4], C[5]=$C[5] (conID C[2]=$C[2])\n";
    if ( $idxLine >= 0) {
      $what[$idxLine]=$C[1]; # RING
      $SIP_INorOUT_Call[$idxLine] = "IN"; # IN==RING (or OUT)
      $timestamps[$idxLine] = $C[0]; 
      $SIP_ConID[$idxLine] = $C[2]; # ConnectionID
      $externalNames[$idxLine] = $externalName;
      $phonebookNames[$idxLine]=$book;
      $NebenstelleNrName[$idxLine]=""; # noch unbekannt
      $externalNumbers[$idxLine] = $externalNumber; # $C[3] Externe Anrufer-Nummer # e.g. 9876543#
      if ($numberFormated ne "") {
        $externalNumbers[$idxLine] = $numberFormated;
        }
      $ownLineNumberNames[$idxLine]=$ownLineNumber;
      my $cnt = $#lineNames; # $#lineNames;
      if ( $idxLine <= $#lineNames) { # Name vorhanden
        $ownLineNumberNames[$idxLine]=$lineNames[$idxLine]; 
        }
      print "For Line $ownLineNumber Index $idxLine and Name $ownLineNumberNames[$idxLine] found\n";
      #Schaltet die HM Systemvariable für den entsprechenden SIP Account auf belegt:
      sendToCcu ($idxLine, "RING", $externalNumber, $externalName, $book, $ownLineNumber, ""); # Nebenstelle noch nicht bekannt!
      startScript($idxLine, "RING", $externalNumber, $externalName, $book, $ownLineNumber, "");
      }
    else {
      # Error: OwnLineNumber not configured 
      }  
    }

  if ( $C[1] eq "CALL" ) { #Ausgehender Anruf
    #Rückgabewerte des Internen Fritzbox Anrufmonitor
    # $C[0] = Datum, $C[1] = "CALL", $C[2] = ConnectionID
    # $C[3] = Nebenstellen-Nr (z.B. 21 für **621)
    # $C[4] = Genutzte eigene Rufummer (Leitung)
    # $C[5] = Angerufene externe Rufnummer

    my $externalNumber=$C[5];
    my ($externalName, $book, $numberFormated)=number2nameBook($externalNumber);
    my $Nebenstelle=expandNebenstelle($C[3]);
    my $idxLine = getLineNumberIdx($C[4], $C[1]);
    if ( $idxLine >= 0) {
      $what[$idxLine]=$C[1]; # CALL
      $SIP_INorOUT_Call[$idxLine] = "OUT"; # ==CALL
      $timestamps[$idxLine] = $C[0]; 
      $SIP_ConID[$idxLine] = $C[2]; # ConnectionID
      $externalNames[$idxLine] = $externalName;
      $phonebookNames[$idxLine] = $book;
      $externalNumbers[$idxLine] = $externalNumber;
      if ($numberFormated ne "") {
        $externalNumbers[$idxLine] = $numberFormated;
        }
      #Prüfen ob eigene Nebenstelle im Telefonbuch vorhanden ist
      $NebenstelleNrName[$idxLine] = expandNebenstelle($C[3]); # Nr. (z.B. 11) oder Name (z.B. Flur)
      doExecLog(6, "CALL mit NS $C[3]=$NebenstelleNrName[$idxLine]");
      $ownLineNumberNames[$idxLine]=$C[4];
      if ( $idxLine <= $#lineNames) {
        $ownLineNumberNames[$idxLine]=$lineNames[$idxLine]; 
        }
      sendToCcu ($idxLine, "CALL", "$externalNumber", "$externalName", $book, $ownLineNumberNames[$idxLine], "$NebenstelleNrName[$idxLine]");
      #                      0          1                 2            3     4 Ltg       5
      startScript ($idxLine, "CALL", "$externalNumber", "$externalName", $book, $ownLineNumberNames[$idxLine], "$NebenstelleNrName[$idxLine]");
      print "\n";
      }
    print "Call von Nebenst. C[3]=$C[3] ($Nebenstelle) bei C[5]=$C[5] ($externalName) über Leitung C[4]=$C[4] (ConectionID C[2]=$C[2])\n";
    }

  if ( $C[1] eq "CONNECT" ) { #Verbundener Anruf
    #Rückgabewerte des Internen Fritzbox Anrufmonitor
    # $C[0] = Datum, $C[1] = CONNECT, $C[2] = ConnectionID
    # $C[3] = Nebenstelle
    # $C[4] = Verbundene-Rufummer

    my $idxLine = getConIdx($C[2], $C[1]);
    if ( $idxLine >= 0) {
      $timestamps[$idxLine] = $C[0]; 
      print "Index is $idxLine verbunden...\n";
      $NebenstelleNrName[$idxLine] = expandNebenstelle($C[3]); # Nr der Nebenstelle (z.B. "22"), welche den Ruf angenommen hat
      }
    sendToCcu ($idxLine, "CONNECT $SIP_INorOUT_Call[$idxLine]", "$externalNumbers[$idxLine]", "$externalNames[$idxLine]", "$phonebookNames[$idxLine]", "$ownLineNumberNames[$idxLine]", "$NebenstelleNrName[$idxLine]");
    startScript ($idxLine, "CONNECT", "$externalNumbers[$idxLine]", "$externalNames[$idxLine]", "$phonebookNames[$idxLine]", "$ownLineNumberNames[$idxLine]", "$NebenstelleNrName[$idxLine]");
    }

  #Verbindung beenden#
  #Rückgabewerte des Internen Fritzbox Anrufmonitor
  # $C[0] = Datum, $C[1] = DISCONNECT, $C[2] = ConnectionID 
  # $C[3] = Dauer in Sekunden
  if ( $C[1] eq "DISCONNECT" ) {
    my $idxLine = getConIdx($C[2], $C[1]);
    if ( $idxLine >=0 ) {
      print "Disconnect at $C[0], previously: $timestamps[$idxLine]\n";
      # $timestamps[$idxLine] = $C[0]; # this would be actual disconnect timestamp, stay with connect timestamp!
      my $lineNo=1+$idxLine;
      print "Line #$lineNo (ConID=$C[2]) disconnected...\n";

      #Schaltet die HM Systemvariable für den entsprechenden SIP Account auf Frei!
      #system "curl 'http://'$IP_CCU'/config/xmlapi/statechange.cgi?ise_id='$SIP_IseID[$idxLine]'&new_value=0'";
      sendToCcu ($idxLine, "DISCONNECT $SIP_INorOUT_Call[$idxLine]", "$externalNumbers[$idxLine]", "$externalNames[$idxLine]", "$phonebookNames[$idxLine]", "$ownLineNumberNames[$idxLine]", "$NebenstelleNrName[$idxLine]");
      startScript ($idxLine, "DISCONNECT", "$externalNumbers[$idxLine]", "$externalNames[$idxLine]", "$phonebookNames[$idxLine]", "$ownLineNumberNames[$idxLine]", "$NebenstelleNrName[$idxLine]");
      print "\n";
      my $timestring="";
      my $dir = "";
      if ($C[3] ne 0) { # nach CONNECT
        #Anrufdauer - Sekunden in mm:ss umrechen
        my $RestSekunden = $C[3];
        my $Minuten = int($RestSekunden / 60);
        $RestSekunden %= 60;
        $timestring = sprintf("%02d:%02d",$Minuten,$RestSekunden);
        if ($SIP_INorOUT_Call[$idxLine] eq "IN") { # nach IN - CONNECT
          $dir = 'in';
          }
        else { # nach CALL - CONNECT
          $dir = 'out';
          }
        }
      else { # erfolglos
        if ($SIP_INorOUT_Call[$idxLine] eq "IN") { # nach RING ohne CONNECT
          $dir = 'missed';
          }
        else { # nach CALL ohne CONNECT
          $dir='failed';
          }
        }  
      my $extNum = $externalNumbers[$idxLine];
      $extNum =~ s/#$//; # remove trailing #, which is send from FB for outgoing calls
      # $NebenstelleNrName[$idxLine] # Nr oder Name
      my $txtLine="$dir;$timestamps[$idxLine];$extNum;$externalNames[$idxLine];$phonebookNames[$idxLine];$ownLineNumberNames[$idxLine];$NebenstelleNrName[$idxLine];$timestring\n";      
      print "$txtLine";
      print "CALL_OUT_NOCONNECT=$cfgHashs{CALL_OUT_NOCONNECT}\n";
      doExecLog(7, "CALL_OUT_NOCONNECT=$cfgHashs{CALL_OUT_NOCONNECT}");
      if (("$dir" eq "failed") && ($cfgHashs{CALL_OUT_NOCONNECT} eq "false")) {
        print "CALL without CONNECT skipped\n";
        }
      else {
        my $new=0;
        if ( -e "$varFilePath/calls.txt") { # append
          open(FILE, ">>", "$varFilePath/calls.txt"); # write the data of the call to the 'permanent' file
          }
        else { # create
          $new=1;
          open(FILE, ">", "$varFilePath/calls.txt");
          }  
        print FILE $txtLine;
        close(FILE);
        if ($new) { # change the owner and permission of the new file:
          chmod 0744, "$varFilePath/calls.txt";
          my $uid   = getpwnam($pkgName);
          my $gid   = getgrnam($pkgName);
          print ("uid:gid of $pkgName: $uid:$gid");
          if (($uid != 0) && ($gid != 0)) {
            chown $uid, $gid, "$varFilePath/calls.txt";
            }        
          }
        }
      #clean up:
      $SIP_ConID[$idxLine]="";
      $externalNumbers[$idxLine]="";
      $NebenstelleNrName[$idxLine]="";
      $SIP_INorOUT_Call[$idxLine]="";
      } # ConnectionID war OK
    } # DISCONNECT

  # if active call: write info memory mapped file /dev/shm/callmonitor.Actual for calls.cgi:
  my $txtlines="";
  my $n=0;
  for my $i (0 .. $#SIP_ConID) {
    if (defined $SIP_ConID[$i]) {
      if ($SIP_ConID[$i] ne "") {
        my $lineNr1= 1 + $i;
        $n++;
        my $lineTxt="$SIP_INorOUT_Call[$i];$C[0];$externalNumbers[$i];$externalNames[$i];$phonebookNames[$i];$ownLineNumberNames[$i];$NebenstelleNrName[$i];\n"; # no duration
        $txtlines="$txtlines$lineTxt"; 
        print("Line $lineNr1 is busy: $lineTxt\n");
        }
      else {
        print("SIP_ConID[$i] empty\n");
        }  
      }
    else {
      print("SIP_ConID[$i] undef: /dev/shm/callmonitor.Actual not deleted when call was finished?\n");      
      }
    }
  if ($txtlines eq "") {
    if ( $cfgHashs{"LOGLEVEL"} < 8 ) {
      truncate "/dev/shm/callmonitor.Actual", 0;
      print "No actual active calls";
      }
    else {
      doExecLog(8, "Due to LOGLEVEL >= 8 file /dev/shm/callmonitor.Actual not truncated to zero");
      }  
    }
  else {  
    print "sending to /dev/shm/callmonitor.Actual: $txtlines";
    unless (open(fh1, ">", "/dev/shm/callmonitor.Actual")) {
      print "Error Opening /dev/shm/callmonitor.Actual\n";
      doExecLog(2, "Error Opening /dev/shm/callmonitor.Actual");
      }
    print fh1  "$txtlines";
    close(fh1);
    my $uid   = getpwnam($pkgName);
    my $gid   = getgrnam($pkgName);
    # print ("uid:gid of $pkgName: $uid:$gid");
    if (($uid != 0) && ($gid != 0)) {
      chown $uid, $gid, "/dev/shm/callmonitor.Actual";
      }
    chmod 0744, "/dev/shm/callmonitor.Actual";
    print "$n actual active calls put to /dev/shm/callmonitor.Actual\n";
    }  
  } # while(<$sock>) Endless loop


sub sendToCcu {
  my ($idxLine, $dir, $externalNumber, $externalName, $phonebook, $ownNumber, $Nebenstelle) = @_;
  # $idxLine, "RING", $externalNumber, $externalName, $book, $ownLineNumber, ""
  # $idxLine, "DISCONNECT $SIP_INorOUT_Call[$idxLine]", "$externalNumbers[$idxLine]", "$externalNames[$idxLine]", "$phonebookNames[$idxLine]", "$ownLineNumberNames[$idxLine]", "$NebenstelleNrName[$idxLine]");

  # my $x1 = encode("iso-8859-1", decode("utf8", $x0)); # o.k.
  # my $x1 = encode("iso-8859-1", $x0); # LÃ¼denscheid SÃ¤ntis MÃ¼ller witout the "use utf8", o.k. with "use utf8"
  $externalName =~ s/;/,/g;      # könnte ';' enthalten
  my $ccuSvText="$dir;$externalNumber;$externalName;$phonebook;$ownNumber;$Nebenstelle";
  my $curlDataI=encode("ISO-8859-1", "Status=dom.GetObject(\"$CCU_SysVars[$idxLine]\").State(\"$ccuSvText\")");
  # print "curlDataI=$curlDataI\n";
  # system "curl 'http://'$IP_CCU'/config/xmlapi/statechange.cgi?ise_id='$SIP_IseID[$idxLine]'&new_value=1'";
  my $upI=encode("iso-8859-1", "$cfgHashs{CCU_USER}:$cfgHashs{CCU_PW}");
  my $ret=system("curl -u $upI -G --data-urlencode '$curlDataI' 'http://$cfgHashs{IP_CCU}:8181/test.exe'");
  my $res=$!;
  doExecLog(4, "sendToCcu(): res=$res, ret='$ret'");
  if ( "$NOTIFY_USERS" ne "" ) {
    # $dsmappname is setup in INFO file, e.g. "SYNO.SDS._ThirdParty.App.callmonitor"
    # $dsmappname needs to match the .url in ui/config. Otherwise synodsmnotify will not work
    # app1:title01 and app1:msgX as 'preloadTexts' in ui/config
    # title01, msg1 in Section [app1] in ui/texts/<lng>/strings with e.g placeholders {0}
    # msg2="Error during sending of call information to HomeMatic CCU {0} with account '{1}': {2}"
    system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg2", "http://$cfgHashs{IP_CCU}:8181", "$cfgHashs{CCU_USER}", "$res: $ret");
    }
  }


sub startScript {
  my ($idxLine, $dir, $externalNumber, $externalName, $phonebook, $ownNumber, $Nebenstelle) = @_;
  my $scriptFilePathName=$cfgHashs{"SHELL_SCRIPT"};
  $scriptFilePathName =~ s/^\s+|\s+$//g; # trim
  if ($scriptFilePathName eq "") {
    return;
    }
  if (-x $scriptFilePathName) {
    my $ret=system("$scriptFilePathName", "$dir", "$externalNumber", "$externalName", "$phonebook", "$ownNumber", "$Nebenstelle");
    my $res=$!;
    doExecLog(4, "startScript(): res=$res, ret='$ret'");
    return;    
    }
  doExecLog(1, "Error: File '$scriptFilePathName' is not executable!");
  }

