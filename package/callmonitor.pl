#!/usr/bin/perl

# Idea from eiGelbGeek 2017
#Version 0.?, muliple code rewritten, using arrays, CardDAV-reading added, ....
# Horst Schmid 2025

use utf8;

use strict;
use warnings;
use File::Basename;
use File::Spec;
use warnings 'all';
# use Env;
use Symbol 'gensym'; # vivify a separate handle for STDERR in open3
use Encode;
use POSIX qw/strftime/;
# https://stackoverflow.com/questions/8733131/getting-stdout-stderr-and-response-code-from-external-nix-command-in-perl

# include-current-directory to @INC:
# https://stackoverflow.com/questions/46549671/doesnt-perl-include-current-directory-in-inc-by-default
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname( abs_path( $0 ) );
use common; # use module common.pm with sub read_fileItem, ...
use vars qw(%cfgHashs); # import is not yet working

my %telBook = (); # Telefonbuch der vollständigen Nummern, 
    # key=bereinigte Nummer, item=($name, $book, $number0 (OriginalFormat), $url, $email)
my %telBookWild = (); # Telefonbuch der WildcardNummern oder Vorwahlen
# my %langTxts = (); # Texte aus ui/texts/<userLanguage>/lang.txt
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

# my %cfgHashs;
my $dsmappname;

# my $country; # exported from common.pm
# my $areaCode; # exported from common.pm
# my $vaz;
my $duplicatesList="";

sub processDuplBookEntry {
  my ( $number, $number0, $number1, $name1, $book1, $url1, $email1, $whatsApp1, $type1, $name2, $book2, $url2, $email2, $whatsApp2, $type2, @others ) = @_;
  # e.g 0049892345 0892345 2345
  my $book = $book1;
  if ($name1 ne $name2) {
    if ($number0 eq $number1) {
      $duplicatesList .="For number $number ($number0) we have different names: $name1 (Book $book1) and $name2 (Book $book2)<br>";
      }
    else {
      $duplicatesList .="For number $number ($number0, $number1) we have different names: $name1 (Book $book1) and $name2 (Book $book2)<br>";
      }
    }
  if ($book1 ne $book2) {
    $book = "$book1, $book2";
    }
  elsif ($name1 eq $name2) {
    my $number0c=removeNonDigits($number0);
    my $number1c=removeNonDigits($number1);
    if (length($number0c)==length($number1c)) {
      if ($number0 ne $number1) {
        $duplicatesList .= "Number $number ($number0, $number1) for '$name1' found duplicate in book $book<br>";
        }
      else {
        $duplicatesList .= "Number $number ($number0) for '$name1' found duplicate in book $book<br>";
        }  
      }
    else { # e.g. For number 00498416600 (0841 6600, 6600) we have
      print "No log entry (numbers effectivly identically): Number $number ($number0, $number1) for '$name1' found duplicate in book $book\n";
      }
    }
  if ($url1 eq "") {
    $url1= $url2;
    }
  if ($email1 eq "") {
    $email1 = $email2;
    }
  elsif (($email1 ne $email2) && ($email2 ne "")) {
    # print "merging needed: email1=$email1 with email2=$email2\n";
    my @emails2=split(",%20", $email2);
    foreach (@emails2) {
      if (index($email1, $_) == -1) {
        $email1 = $email1 . ",%20" . $_;
        }
      }
    # print "merging done: email=$email1\n";
    }
  if ($whatsApp1 eq "") {
    $whatsApp1 = $whatsApp2;
    }
  return ($name2, $book, $number, $url1, $email1, $whatsApp1, $type1);
  }


# Insert number and Name to internal hash table
sub insertToTelBook {
  my ( $number0, $name, $book, $url, $email, $whatsApp, $type, @others ) = @_;
  # $number0 possibly without area code
  my $number1 = addCountryArea($number0);
  $name =~ s/;/ /g; # Replace semcolon by space as semicolon is later our list separator
  if ($number1 =~ /.*\*$/) { # with '*' at the end
    # print("WildCard: $number1 $name, book='$book' ");
    $number1 =~ s/\*/\.\*/; # replace * by the regExp .*
    # print("$number1\n");
    my @ar=($name, $book, $number0, $url, $email, $whatsApp, $type);
    if (exists($telBookWild{$number1})) { # e.g. from another phone book or duplicate in actual file
      my ($name2, $book2, $number02, $url2, $email2, $whatsApp2, $type2)=@{$telBookWild{$number1}};
      @ar=processDuplBookEntry($number1, $number0, $number02, $name2, $book2, $url2, $email2, $whatsApp2, $type2, $name, $book, $url, $email, $whatsApp, $type);
      }
    $telBookWild{$number1}=[@ar];
    }
  else { # normal number
    # print("Normal: $number0 $name book=$book type='$type'\n");
    my @ar=($name, $book, $number0, $url, $email, $whatsApp, $type);
    if (exists($telBook{$number1})) { # from another phone book already available
      my ($name2, $book2, $num02, $url2, $email2, $whatsApp2, $type2)=@{$telBook{$number1}};
      @ar=processDuplBookEntry($number1, $number0, $num02, $name2, $book2, $url2, $email2, $whatsApp2, $type2, $name, $book, $url, $email, $whatsApp, $type);
      }
    $telBook{$number1} = [@ar];
    # https://stackoverflow.com/questions/5384825/perl-assigning-an-array-to-a-hash
    # $telBook{$number}=($name, $book);
    }
  }


#Simple Text-Telefonbuch-Datei (incl. Nebenstellennamen!?) einlesen:
sub read_txt_telBook {
  my ($filePathName, $book, @others ) = @_;
  if ( ! (-e -f -r $filePathName)) {  # not (exists, not directory but file, readable)
    fileMissingLogEntry($filePathName);
    return;  
    }
  my $coding="<:encoding(UTF-8)";
  print "reading book '$book' ($filePathName) ...\n";
  open(IN, $coding, $filePathName) or do {
    my $err=$!;
    my $errMsg="Error to open phonebook file '$filePathName' ($book) for reading: $err\nNot available? No permission? Locked by other process?";
    print "$errMsg";
    doExecLog(1, $errMsg);
    # msg2: "Fehler beim Lesen/Aktualisieren des Telefonbuchs {0}: {1}"
    # system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg2", "$filePathName  ($book)", "$err");    
    return ();
    }; 
  my $n=0;
  while(<IN>){
    chomp;
    # s/\A\N{BOM}//;
    # print("1st:" . ord(substr($_,0,1))); # 239 ???
    s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
    if (($_ ne '') && (substr($_, 0, 1) ne '#')) {
      # print "line='$_'\n";
      my $line=encode('utf-8', $_); # why is this needed?
      my @elements = split(":", $line, 2); # expected separator
      if ($#elements < 1) {
        @elements = split(";", $line, 2); # alternative separator
        }
      my $number=$elements[0];
      # print "line='$_' => '$number':'$elements[1]'\n";
      insertToTelBook($number, $elements[1], $book, "", "", "", ""); # no URL for Homepage, no eMail, no WhatsApp, no type (FAX, CELL, pref)
      $n++;
      }
    }
  close(IN);
  doExecLog(7, "$n items read from $filePathName");
  print "$n items read from $filePathName\n";
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
  my @numbers=(); # number + type
  my @urls=();
  my @emails=();
  my @whatsApp=();
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
    elsif (($line =~ /^URL/ ) || ($line =~ /.URL:/ )) {
      # print " URL: $line \n";
      my($pre, $url) = split(/:/, $line, 2); # only 2 parts, split at 1st ":"
      $url =~ s/\\//g; # we may have "URL: URL;TYPE=WORK:http\\://www.mlp-banking.de"
      # print "URL found in CardDAV: $url ($pre)\n";
      my @u=($url, $pre);
      push(@urls, \@u); 
      }      
    elsif (uc($line) =~ /^EMAIL/ ) { # e.g. EMAIL;TYPE=INTERNET,HOME
      # (type = aol, applelink, attmail, cis, eworld, internet(default), ibmmail, mcimail, powershare, prodigy, tlx, x400)
      my($pre, $email) = split(/:/, $line, 2);
      my $use=1;
      if (index(uc($pre), ";TYPE=") != -1) { # type is specified
        if (index(uc($line), "INTERNET") == -1) { # type is not INTERNET
          $use=0; # ignore types aol, ... x400
          }
        }
      chomp $email;
      if ($email eq "") {
        $use=0;
        }
      if ($use==1) {
        push(@emails, $email);
        }
      }      
    elsif (uc($line) =~ /^IMPP/ ) { # e.g. IMPP;TYPE=whatsapp:<nummer> or IMPP;TYPE=personal,pref:WhatsApp:alice@example.com
      # (type = ??)
      chomp $line;
      print "Instant Messaging $name: $line\n";
      if (index(lc($line), "whatsapp") > -1) {
        my @items = split(/:/, $line);
        my $number = $items[$#items];
        chomp $number;
        # print "  Number: $number\n";
        $number = addCountryArea($number); # uses e.g. 0049, 00 needs later be replaced by %2B
        # print "  Number: $number\n";
        push(@whatsApp, $number);
        }
      }      
    elsif ($line =~ /^TEL/ ) {
      # print " TEL: $line \n";
      # TEL;TYPE=FAX,WORK:0731 ...
      # TEL;TYPE=PREF,WORK:0731 ...
      # TEL;TYPE=work:069 ...
      # TEL;TYPE=CELL:0160 ...

      my($pre, $number) = split(/:/, $line);
      my @elements=split(";", uc($pre));
      # print "$number: $pre=$pre\n";
      my $type="";
      foreach (@elements) {
        if ($_ =~ /^TYPE=/) {
          s/^TYPE=//;
          # print "$number: TYPE=$_\n";
          $type=$_;
          }
        }
      my @item=($number, $type);
      push(@numbers, \@item);
      # print "pushed ($number, $type)\n";
      }      
    elsif ($line =~ /END:VCARD/ ) {
      if ($fullName ne "") {
        # print("Entry: $fullName\n");
        $name=$fullName;
        }
      elsif($name ne "") { # no FN, only N
        $name =~ s/^N://;
        $name =~ s/;//g;
        $name =~ s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
        }
      if ($name ne "") { # normaly we should have a name!
        # in case of "item1.URL" or "w5ozm8.URL" we would need to read the line "item1.X-ABLabel" or "w5ozm8.X-ABLABEL"
        $name =~ s/\\//; # sometimes "\,"
        my $n = 1 + $#numbers; # n numbers for one Name
        # print(" $n numbers: $name book='$bookName'\n"); # warum fehlt erstes Zeichen???
        my $mUrl=0;
        foreach (@numbers) {
          # we may have multiple numbers (different type) for one name
          my ($num1, $type)=@{$_};
          # print "retrieved: '$num1', '$type'\n";
          my $url="";
          my $email="";
          my $whats="";
          if ($#urls > -1) { # we have at least one URL
            my $nn=1+$#urls;
            # print "$nn URLs found\n";
            if ($mUrl > $#urls) { # less URLs than numbers
              $mUrl=$#urls; 
              }
            my ($u, $pre)=@{$urls[$mUrl]};
            # my @newa = @$ra;   # copy by assigning  
            $url=$u;
            # print "Using URL 0: $url ($pre)\n";
            # print "Using URL $m: $url ($pre)\n";
            }
          if ($#emails > -1) { # we have at least one entry
            my $nn=1+$#emails;
            if ($nn > 1) {
              print "$nn emails (" . join(", ", @emails) . ") found for $num1\n";
              }
            $email = join(",%20", @emails);
            }  
          if ($#whatsApp > -1) {
            $whats = $whatsApp[0];
            }
          # print "#### inserting $num1 ($type) for '$name' ####\n";
          insertToTelBook($num1, $name, $bookName, $url, $email, $whats, $type); # make an Entry for each number
          $mUrl++;
          }          
        $fullName="";
        $name="";
        @numbers=();
        @urls=();
        @emails=();
        @whatsApp=();
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
  my $rn; # realName
  my $type; # e.g. "work", "home", "fax_work"
  # my $number;
  my @numbers=(); # number + type
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
    my $errMsg="Error to open phonebook file '$filePathName' ($book) for reading: $err";
    print "$errMsg\n";
    doExecLog(1, $errMsg);
    fileMissingLogEntry($filePathName);
    # msg2: "Fehler beim Lesen/Aktualisieren des Telefonbuchs {0}: {1}"
    # system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg2", "$filePathName  ($book)", "$err");    
    return ();
    };

  sub start { # of XML item
    my($p, $tag, %attrs) = @_;
    $is_phb = ($tag eq "phonebook");
    $is_number = ($tag eq "number");
=pod
    if (($is_phb) || ($is_number)) {
      print "start tag=$tag, attrs=";
      keys %attrs; # reset the internal iterator so a prior each() doesn't affect the loop
      while(my($k, $v) = each %attrs) { 
        print " $k=$v";
        }
      print " book1=$attrs{'name'}\n";
      }
=cut
    if ($is_number) {
      keys %attrs; # reset the internal iterator so a prior each() doesn't affect the loop
      while(my($k, $v) = each %attrs) {
        if ($k eq "type") {
          # print " $k=$v\n";
          $type=$v;
          }
        }
      # print " book1=$attrs{'name'}\n";
      }
    if ($is_phb) {
      if ($book eq "") { # overwrite configured book name by the exported name
        $book1=$attrs{"name"};
        }
      }
    $is_realName = ($tag eq "realName")
    } # sub start
 
  sub text { # text of xml item: If it's a name, cache it, it its a number: put it to hash table
    my($p, $text) = @_;
    chomp($text);
    $text=encode('utf-8', $text); ## with use utf8 still required???
    $text =~ s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
    if ($text ne "") {
      # print("txt=$text, num=$is_number, rn=$is_realName\n");
      if ($is_realName) {
        $text =~ s/&amp;/&/g; # &amp; ==> & 
        # gibt es sonstiges zu decodieren?
        $rn=$text;
        }
      elsif ($is_number) {
        $text =~ s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
        my @item=($text, $type);
        push(@numbers, \@item);
        $type="";
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
        foreach (@numbers) {
          my ($num1, $type)=@{$_};
          insertToTelBook($num1, $rn, $book1, "", "", "", $type); # make an Entry for each number, no Homepage-URL, no eMail, no whatsApp, no type
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


# FritzBox liefert z.B. 22 für Nebenstelle **622, dies wird umgewandelt. Falls z.B. **621 im TB, dann wird Name zurückgegeben.
sub expandNebenstelle {
  chomp;
  my ($ns0) = @_;
  $ns0 =~ s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
  my $len=length($ns0);
  # print "expandNebenstelle '$ns0' (len=$len) ...\n";
  if ($len==1) {
    $ns0="**$ns0"; # 1 ==> **1
    }
  else { # length() == 2
    my $ns=$ns0;
    $ns0="**6$ns0"; # 21 ==> **621
    print "Nebenstelle FB=$ns ==> $ns0\n";
    doExecLog(3, "Extension FB=$ns ==> $ns0");    
    }  
  if (exists($telBook{$ns0})) { # wenn im Telefonbuch vorhanden: Namen (z.B. "Flur") statt Nr (z.B. 11 bzw **611) verwenden
    my ($ns1, $book, $numberFormated, $url, $mail, $whatsApp, $type)=@{$telBook{$ns0}}; # $name, $book, $number0 (OriginalFormat)
    print "Ext. $ns0 via $book resolved to $ns1\n";
    doExecLog(4, "Ext. $ns0 via $book resolved to $ns1");    
    $ns0=$ns1;
    }
  else {
    print "Ext. '$ns0' could not be resolved to a name\n";
    doExecLog(3, "Ext. $ns0 konnte nicht zu Namen aufgelöst werden");    
    }  
  return $ns0; # e.g. 22 ==> **622 or "Home Office"
  }


sub makeCallListEntry {
  my ($dir, $timestamp, $extNum, $externalName, $phonebookName, $ownLineNumberName, $NebenstelleNrName, $timestring) = @_;
  $extNum =~ s/#$//; # remove trailing #, which is send from FB for outgoing calls
  # $NebenstelleNrName[$idxLine] # Nr oder Name
  my $txtLine="$dir;$timestamp;$extNum;$externalName;$phonebookName;$ownLineNumberName;$NebenstelleNrName;$timestring\n";
  # would we need URI-Encoding for the external name, if it contains e.g. ">" or "&"?????
  print "$txtLine";
  #print "CALL_OUT_NOCONNECT=$cfgHashs{CALL_OUT_NOCONNECT}\n";
  #doExecLog(7, "CALL_OUT_NOCONNECT=$cfgHashs{CALL_OUT_NOCONNECT}");
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
      print ("uid:gid of $pkgName: $uid:$gid\n");
      if (($uid != 0) && ($gid != 0)) {
        chown $uid, $gid, "$varFilePath/calls.txt";
        }        
      }
    }
  }


sub fileMissingLogEntry {
  my ($fn, @others)=@_;
  my $account=getpwuid($<);
  my $lsl=`ls -l $fn 2>&1`;
  chomp $lsl;
  my $synoacl=`synoacltool -get-perm $fn $account`;
  doExecLog(1, "File '$fn' is missing or not accessible with the account " . $account . "<br>$lsl<br>Not available? No permission? Locked by other process?<br>synoacltool -get-perm $fn $account<br> $synoacl");
  print "File $fn is missing (account $account)\n$lsl\n$synoacl";
  }


# after a phonebook update check the calls list for "Unknown" entries and add the name, if it's now in the phonebook
sub updateCallsList{
  my ($file) = @_;
  print "sub updateCallsList for '$file'\n";
  if(-e -w $file) {
    open my $fh, '>', "${file}new";
    open (my $fh0, "$file");
    my $cnt=0;
    while( my $line = <$fh0>) {
      chomp $line;
      $cnt++;
      # print "$line\n";
      my $upd=0;
      my @items = split(";", $line);
      my ($externalName, $book, $numberFormated, $url, $email, $whatsApp, $type);
      my $number;
      if ( $items[3] =~ /^Unknown/ ) {
        print "  items[3] = '$items[3]'\n";
        $number=$items[2]; # my be "<a href='...'>07524</a> 990132"
        $number =~ s/<\/a>//g;
        $number =~ s/<.*>//g;
        print "  number = '$number' ";
        ($externalName, $book, $numberFormated, $url, $email, $whatsApp, $type)=number2nameBook($number);
        if ( $externalName ne "Unknown") {
          $upd=1;
          print " now resolved to '$externalName'!\n";
          }
        else {
          print " still un-resolved!\n";
          }  
        }
      if ( $upd == 1) {
        # my $txtLine="$dir;$timestamp;$extNum;$externalName;$phonebookName;$ownLineNumberName;$NebenstelleNrName;$timestring\n";
        print "==> new text line with '$externalName'\n";
        my ($extName, $extNumber) = appendLinks2extName($externalName, $url, $email, $whatsApp, $type, $number);
        my $txtLine="$items[0];$items[1];$extNumber;$extName;$book;$items[5];$items[6];$items[7]\n";
        print $fh $txtLine;
        }
      else {
        print $fh "$line\n";
        }
      } # while
    print "  $cnt lines scanned!\n";
    close ($fh0);
    close ($fh);
    chmod 0744, "${file}new";
    my $uid = getpwnam($pkgName);
    my $gid = getgrnam($pkgName);
    print ("uid:gid of $pkgName: $uid:$gid\n");
    if (($uid != 0) && ($gid != 0)) {
      chown $uid, $gid, "${file}new";
      }        
    unlink($file); # delete the old file
    rename("${file}new", "${file}"); # rename ${file}new to ${file}
    }
  else {
    print "Warning: File '$file' not found!\n";
    }  
  }



# Lookup the name for a given number in the hash tables
sub number2nameBook {
  # find the given Number either in $telBook{$number} or in $telBookWild{$key}
  my ($number0) = @_;
  my $number = addCountryArea($number0);
  my $telCnt = keys %telBook;
  print "scanning for $number ... ($telCnt entries in telbook)";
  # doExecLog(6, "number2nameBook(), cleaned number='$number'");
  if (exists($telBook{$number})) { # normal number
    my ($callerName, $bookName, $numberFormated, $url, $mail, $whatsApp, $type)=@{$telBook{$number}};
    doExecLog(6, "number2nameBook(), number='$number0', cleaned='$number' resolved to $callerName, $bookName");
    print "found in $bookName: '$callerName\n";
    return($callerName, $bookName, $numberFormated, $url, $mail, $whatsApp, $type);
    }
  print " not in normal telbook, scanning wildCardBooks...";
  my $len1=0;
  my ($name, $book, $numberFormated, $url, $mail, $whatsApp, $type);
  foreach my $key (keys %telBookWild) { # Find e.g. Entry "0032*:Belgium_" for 00326875676
    # Hint: The key is no more the original e.g. 0032* but an regular expression: <number>.* (number followed by anything, 0032.*)
    if ( $number =~ /^$key/ ) {
      my $len2=length($key)-2; # count of real digits
      if ($len2 > $len1) { # previously e.g. len1=4 from 0049, now len2=6 from 004989
        ($name, $book, $numberFormated, $url, $mail, $whatsApp, $type)=@{$telBookWild{$key}};
        $len1=$len2;
        }
      }
    }
  if ($len1 > 0) {
    # my $name=$telBookWild{$key} . " " . substr($number, $len); # return e.g. Belgium 6875676
    $name = $name . " " . substr($number, $len1); # return e.g. Belgium 6875676
    doExecLog(6, "number2nameBook(), number='$number0', cleaned='$number' resolved to $name from $book");
    $numberFormated=substr($number, 0, $len1) . " " . substr($number, $len1); 
    # print "number2nameBook() $numberFormated found in $book as $name. AREABookName=$cfgHashs{BOOKNAME_AREA}\n";
      if (index($book, $cfgHashs{BOOKNAME_AREA}) == -1) {
        # e.g. the wildcard number of an company, don't insert "Unknown "
        return ($name, $book, $numberFormated, $url, "", "") # [CallerName, BookName, original formated number]
        }
      # print "number2nameBook() numberFormated=$numberFormated, country=$country, areaCode=$areaCode\n";
      if ( $numberFormated =~ /^$country.*/) { # starts with own country code
        # print "own country found!\n";
         # NUMPLAN
        if ($cfgHashs{NUMPLAN} == 0) {
          # print "offener Nummernplan\n"; # Deutschland, Österreich
          $numberFormated =~ s/^$country/0/; # replace e.g. 0049 by 0, make international number to national number
          } 
        else {
          # print "geschlossener Nummernplan\n"; # Schweiz
          $numberFormated =~ s/^$country//; # remove e.g. 0041, make international number to national number
          }
        }
      if ( $numberFormated =~ /^$areaCode.*/) { # starts with own area code, e.g. 0711
        $numberFormated =~ s/^$areaCode//; # remove that
        }
      print "number2nameBook() numberFormated=$numberFormated\n";
      return ( "Unknown from " . $name, "", $numberFormated,       "",  "",    "",      "") 
      #           Caller-"Name"       , BookName, formated number, url, eMail, whatsApp, type
    }
  doExecLog(6, "number2nameBook(), cleaned number='$number' not resolved");
  print " Number not found!\n";
  return ("Unknown", "", $number, "", "", "", "");
  }



##################### MAIN ##################
print  formatedNow() . basename( $scriptPath ) . " Die Datei $scriptFile liegt im Verzeichnis $scriptDir.\n";
# my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
my $user1 = getpwuid($<);
print "Env LOGNAME='$ENV{LOGNAME}', Env USER='$ENV{USER}', getpwuid<='$user1'\n";
# my $webServerPath = "/PFAD/BIS/ZUM/WEBSERVER";
my $webServerPath = "$scriptDir/ui";

my %tmpHash=read_fileItem dirname($scriptDir) . "/INFO", "dsmappname";
$dsmappname=$tmpHash{dsmappname}; # e.g. "SYNO.SDS._ThirdParty.App.callmonitor", required for synodsmnotify command
=pod
# my $lngUser = "";
# $lngUser = $ENV{SYNOPKG_DSM_LANGUAGE}; # not global DSM language but actual user language! Never 'def'
  # SYNOPKG_DSM_LANGUAGE is not set if executed from shell
my $langFile="$webServerPath/texts/enu/lang.txt"; # here use always Englisch! 
open my $info, $langFile or print "Could not open $langFile: $!\n";
while( my $line = <$info>)  {   
  chomp($line);
  if ( !($line =~ /^#/ ) ) {
    my($key, $val) = split(/=/, $line);
    $line =~ s/\n$//;
    $val =~ s/^"(.*)"$/$1/;
    print "  key='$key', val='$val'\n";
    $langTxts{$key}=$val;
    }
  }
close $info;
print "Example from langFile: noInCall=$langTxts{noInCall}\n";
=cut

my $cntCfg=keys(%cfgHashs); # Import is not yet working!???????????????????????
print "callmonitor.pl: $cntCfg items in cfgHashs\n";

# workaround: Read again! !!!!!!!!!!!!!!!!!!!!!!!!!!!!
# =pod
print "read_fileItem($cfgFilePathName)...\n";
%cfgHashs=read_fileItem "$cfgFilePathName"; # read all items
print "... LogLevel is $cfgHashs{LOGLEVEL}\n";
# doExecLog(4, "Env LOGNAME='$ENV{LOGNAME}', Env USER='$ENV{USER}', getpwuid<='$user1', getpwuid=" . join(" ",  getpwuid($<)) );
# getpwuid e.g.= root *  0   0   /root /bin/ash
#                name pw uid gid home  shell

# $cfgHashs{CCU_PW} and $cfgHashs{DAV_PW} should be set to "*****" in the config file, real PW is in var/pw file (root only access)
%tmpHash=read_fileItem "$varFilePath/pw";
%cfgHashs = (%cfgHashs, %tmpHash);

$vaz = $cfgHashs{VAZintl}; # e.g. 00 in western Europe, 011 in northern America
$country = $cfgHashs{COUNTRYCODE}; # e.g. 0049 for Germany
$country =~ s/^\s*(.*?)\s*$/$1/; # trim ( \s* = multiple Whitespace )
$areaCode=$cfgHashs{AREACODE}; # e.g. 089 for Munich
$areaCode =~ s/^\s*(.*?)\s*$/$1/; # trim
# =cut

# my $cntCfg0=keys(%common::cfgHashs);
# print "callmonitor.pl: $cntCfg0 items in common::cfgHashs\n";

# %cfgHashs = common::cfgHashs;
my $cntCfg=keys(%cfgHashs);
print "callmonitor.pl: $cntCfg items in cfgHashs\n";

if ( ! exists $cfgHashs{IP_FRITZBOX} ) {
  doExecLog(1, "Error: Could not get IP address IP_FRITZBOX of FritzBox from the package config file!");
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
my $fn=$cfgHashs{'TELBOOK_TXT'};
if ($fn ne "") { # Attention: In bash -ne is numerical compare, in Perl ne is string compare!
  print "Scanning TELBOOK_TXT = $fn...\n";
  &read_txt_telBook($fn, $cfgHashs{"BOOKNAME_TXT"});
  }
else {
  print "No TELBOOK_TXT defined\n";
  }
$fn=$cfgHashs{AREABOOK_TXT};
if ($fn ne "") {
  print "Scanning AREABOOK_TXT = $fn...\n";
  &read_txt_telBook($fn, $cfgHashs{BOOKNAME_AREA});
  }
my $telCnt0=keys %telBook;
my $telCntW=keys %telBookWild;
print "TXT $telCnt0 normal entries and $telCntW wildcard entries.\nGoing to read XML files...\n";
if ($#ARGV >= 0) {
  if ($ARGV[0] eq "restart") {
    $msgTbRead="Restarted! ";    
    }
  }
$msgTbRead="${msgTbRead}Read $telCnt0 entries from TEXT-Books";
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
    if ( -e -f -r $cfgHashs{$tb}) {  # exists, not directory but file, readable
      $cnt++;
      &read_xml_telBook($cfgHashs{$tb}, $cfgHashs{$tbn});
      }
    else {  
      fileMissingLogEntry($cfgHashs{$tb});
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
    print("\ncalling read_cardDAV_telBook ${idx} ($cfgHashs{$tbn}): $cfgHashs{$tb} ...\n");
    $cnt++;
    read_cardDAV_telBook($cfgHashs{$tb}, $userX, $passwordX, $cfgHashs{$tbn});
    print("... read_cardDAV_telBook ${idx} ($cfgHashs{$tbn}) done\n");
    }
  else {
    print "$tb is not defined\n";
    }  
  }
if ( length($duplicatesList) > 0) {
  $duplicatesList =~ s/<br>$//;
  doExecLog(4, $duplicatesList);
  }
my $telCnt = keys %telBook;
$telCntW = keys %telBookWild;
my $telCnt3 = $telCnt - $telCnt2;
$msgTbRead="$msgTbRead, $telCnt3 entries from $cnt CardDAV-Books, total $telCnt entries plus $telCntW wildcard entries";
doExecLog(4, $msgTbRead);
print "total telCnt=$telCnt plus $telCntW wildcard entries\n";
# print("WildCard-Test 0032680798: " . number2nameBook("0032680798") . "\n");
# print("Test **623: " . join(" ", number2nameBook("**623")) . "\n");

=pod
# funktioniert nicht, zu kurz nach dem Start der App!!
print "Test-synodsmnotify Class='$dsmappname', target='$NOTIFY_USERS', title1:msg1='Test-Desktop-Message'\n";
my $msg="/usr/syno/bin/synodsmnotify -c $dsmappname $NOTIFY_USERS $pkgName:app1:title1 $pkgName:app1:msg1 Test-Desktop-Message";
print "$msg\n";
doExecLog(6, "$msg");
system("/usr/syno/bin/synodsmnotify", "-c $dsmappname", "$NOTIFY_USERS", "$pkgName:app1:title1", "$pkgName:app1:msg1", "Test-Desktop-Message");
=cut

$SIG{TERM} = sub { doExecLog(3, "stopped by TERM signal!"); die "Caught a sigterm, probably from start-stop-status.\n  $!" };
# zu Testzwecken kann mit Parametern aufgerufen werden:
while ($#ARGV > -1) {
  my $item = shift @ARGV;
  my $len = length($item);
  print "Debug-Argument: '$item' (len=$len)\n";
  if ( lc($item) eq "dump" ) { #### dump: print all phonebook entries before waiting for calls
    # print "$_ $telBook{$_}\n" for (keys %telBook);
    foreach my $key (keys %telBook) {
      my ($name, $book, $raw, $url, $email, $whatsApp, $type)= @{$telBook{$key}};
      print "$key ($raw) $book $name $url $email $whatsApp $type\n";
      }
    }
  elsif ( length($item) <= 2) { #### e.g "22" should be expanded to "*622"
    my $ns = expandNebenstelle($item); # incl. geg. auch in Namen wandeln
    print "$item => $ns\n";
    }
  elsif (( $item =~ /^\d+$/ ) or ($item =~ /^\*\*.*/)) {  #### show phonebook entry for given number
    # print "Number $item: ";
    my ($externalName, $book, $numberFormated, $url, $extEmail, $whatsApp, $type)=number2nameBook($item);
    print "Debug NumberLookup $item: $numberFormated $externalName ($book) url='$url', eMail='$extEmail', WhatsApp='$whatsApp'\n";
    }
  elsif ( $item =~ /^RING/ ) {  #### generate debug call list entry for given number
    my $extNum="0049892345678";
    if ($#ARGV > -1) {
      $extNum = shift @ARGV;
      }
    my ($externalName, $book, $numberFormated, $url, $extEmail, $whatsApp, $type)=number2nameBook($extNum);
    print "Debug RING $extNum: $externalName, $book, $numberFormated, url='$url', eMail='$extEmail', whatsApp='$whatsApp', type='$type'\n";
    my ($extName, $extNum2) = appendLinks2extName($externalName, $url, $extEmail, $whatsApp, $type, $numberFormated);
    print "DEBUG withLinks: $extName\n";
    makeCallListEntry ("in", strftime("%F %T: ", localtime time), $extNum2, $extName, $book, $lineNames[0], "**611", "");
    }
  else {
    print "wrong Parameter '$item', either 'dump', a pure interger number or no parameter are allowed!\n";
    }  
  }

updateCallsList("$varFilePath/calls.txt"); # newest file
updateCallsList("$varFilePath/calls.txt.1"); # previous file (log rotation, still used in web page)

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
my @externalURLs;
my @externalEmails; # option: Append &amp;subject=Your Call from <DateTime>
my @externalWhatsApp;
my @externalType;
my @ownLineNumberNames;
my @phonebookNames;
print  formatedNow() . basename( $scriptPath ) . ": Waiting for calls ...\n";
doExecLog(5, "Waiting for calls ...");
while(<$sock>) { #warten auf aktiven Anruf#

  #Rückgabewerte des Internen Fritzbox Anrufmonitor
  # $C[0] = Datum
  # $C[1] = RING, CALL, CONNECT, DISCONNECT
  # $C[2] = ConnectionID
  # $C[3] = from
  # $C[4] = via or to
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
    my ($externalName, $book, $numberFormated, $url, $email, $whatsApp, $type)=number2nameBook($externalNumber);
    print "RING C[3]=$externalNumber ($numberFormated, $externalName) bei C[4]=Line=$C[4], C[5]=$C[5] (conID C[2]=$C[2])\n";
    if ( $idxLine >= 0) {
      $what[$idxLine]=$C[1]; # RING
      $SIP_INorOUT_Call[$idxLine] = "IN"; # IN==RING (or OUT)
      $timestamps[$idxLine] = $C[0]; 
      $SIP_ConID[$idxLine] = $C[2]; # ConnectionID
      $externalNames[$idxLine] = $externalName;
      $externalURLs[$idxLine] = $url;
      $externalEmails[$idxLine] = $email; # option: Append &amp;subject=Your Call from <DateTime>
      $externalWhatsApp[$idxLine] = $whatsApp;
      $externalType[$idxLine] = $type;
      $phonebookNames[$idxLine]=$book;
      $NebenstelleNrName[$idxLine]=""; # noch unbekannt
      $externalNumbers[$idxLine] = $externalNumber; # $C[3] Externe Anrufer-Nummer # e.g. 9876543#
      if ($numberFormated ne "") {
        # print "RING externalNumber=$externalNumber, numberFormated=$numberFormated\n";
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
    my ($externalName, $book, $numberFormated, $url, $email, $whatsApp, $type)=number2nameBook($externalNumber);
    my $Nebenstelle=expandNebenstelle($C[3]); # Nr. (z.B. $C[3]=23 (statt **623)) oder Name (z.B. Flur)
    my $idxLine = getLineNumberIdx($C[4], $C[1]);
    if ( $idxLine >= 0) {
      $what[$idxLine]=$C[1]; # CALL
      $SIP_INorOUT_Call[$idxLine] = "OUT"; # ==CALL
      $timestamps[$idxLine] = $C[0]; 
      $SIP_ConID[$idxLine] = $C[2]; # ConnectionID
      $externalNames[$idxLine] = $externalName;
      $externalURLs[$idxLine] = $url;
      $externalEmails[$idxLine] = $email;
      $externalWhatsApp[$idxLine] = $whatsApp;
      $externalType[$idxLine] = $type;      
      $phonebookNames[$idxLine] = $book;
      $externalNumbers[$idxLine] = $externalNumber;
      if ($numberFormated ne "") {
        $externalNumbers[$idxLine] = $numberFormated;
        }
      #Prüfen ob eigene Nebenstelle im Telefonbuch vorhanden ist
      $NebenstelleNrName[$idxLine] = expandNebenstelle($C[3]); # Nr. (z.B. 1) oder Name (z.B. Flur)
      doExecLog(3, "CALL mit NS $C[3]=$NebenstelleNrName[$idxLine]");
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
       # wird in **622 oder geg. in den Namen gewandelt.
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
      my ($extName, $extNumber) = appendLinks2extName($externalNames[$idxLine], $externalURLs[$idxLine], $externalEmails[$idxLine], $externalWhatsApp[$idxLine], $externalType[$idxLine], $externalNumbers[$idxLine]);
      makeCallListEntry ($dir, $timestamps[$idxLine], $extNumber, $extName, $phonebookNames[$idxLine], $ownLineNumberNames[$idxLine], $NebenstelleNrName[$idxLine], $timestring);
      #clean up:
      $SIP_ConID[$idxLine]="";
      $externalNumbers[$idxLine]="";
      $externalURLs[$idxLine]="";
      $externalEmails[$idxLine]="";
      $externalWhatsApp[$idxLine]="";
      $externalType[$idxLine] = "";      
      $NebenstelleNrName[$idxLine]="";
      $SIP_INorOUT_Call[$idxLine]="";
      } # ConnectionID war OK
    } # DISCONNECT

  # if active call: write info memory mapped file /dev/shm/callmonitor.Actual for calls.cgi:
  my $txtlines="";
  my $n=0;
  for my $i (0 .. $#SIP_ConID) { # loop through all active calls
    if (defined $SIP_ConID[$i]) {
      if ($SIP_ConID[$i] ne "") {
        my $lineNr1= 1 + $i;
        $n++;
        my ($extName, $extNumber) = appendLinks2extName($externalNames[$i], $externalURLs[$i], $externalEmails[$i], $externalWhatsApp[$i], $externalType[$i], $externalNumbers[$i]);
        my $lineTxt="$SIP_INorOUT_Call[$i];$C[0];$extNumber;$extName;$phonebookNames[$i];$ownLineNumberNames[$i];$NebenstelleNrName[$i];\n"; # no duration
        $txtlines="$txtlines$lineTxt"; 
        print("Line $lineNr1 is busy: $lineTxt\n");
        }
      else {
        print("SIP_ConID[$i] empty\n");
        }  
      }
    else {
      print("SIP_ConID[$i] undef: /dev/shm/$pkgName.Actual not deleted when call was finished?\n");      
      }
    }
  if ($txtlines eq "") { # no active call
    if ( $cfgHashs{"LOGLEVEL"} < 8 ) {
      truncate "/dev/shm/$pkgName.Actual", 0;
      print "No actual active calls";
      }
    else {
      doExecLog(8, "Hint: Due to LOGLEVEL >= 8 the file /dev/shm/$pkgName.Actual was not truncated to zero at the end of the call");
      }  
    }
  else { # write all active calls to /dev/shm/$pkgName.Actual. That will be appended in calls.cgi to the list of finished calls
    print "sending to /dev/shm/$pkgName.Actual: $txtlines";
    unless (open(fh1, ">", "/dev/shm/$pkgName.Actual")) {
      print "Error Opening /dev/shm/$pkgName.Actual\n";
      doExecLog(2, "Error Opening /dev/shm/$pkgName.Actual");
      }
    print fh1  "$txtlines";
    close(fh1);
    my $uid   = getpwnam($pkgName);
    my $gid   = getgrnam($pkgName);
    # print ("uid:gid of $pkgName: $uid:$gid");
    if (($uid != 0) && ($gid != 0)) {
      chown $uid, $gid, "/dev/shm/$pkgName.Actual";
      }
    chmod 0744, "/dev/shm/$pkgName.Actual";
    print "$n actual active calls put to /dev/shm/$pkgName.Actual\n";
    }  

  } # while(<$sock>) Endless loop listening to FritzBox


sub appendLinks2extName {
  my ($extName, $urlWeb, $eMail, $whatsApp, $type, $number) = @_;
  print "called/caller appendLinks2extName($extName, $urlWeb, $eMail, $whatsApp, $type, $number)\n";
  if (index(uc($type), "FAX") != -1)  {
    $extName="<img src='images/fax.png', width='$cfgHashs{SIZE_ICON}', height='$cfgHashs{SIZE_ICON}'>$extName";
    }
  if ($urlWeb ne "") { # Add Homepage-URL to Name
    $extName="$extName <a target='_blank' href='" . $urlWeb . "'><img src='images/web.png', width='$cfgHashs{SIZE_ICON}', height='$cfgHashs{SIZE_ICON}'></a>";
    }
  else {print "  no webUrl\n";}  
  if (($cfgHashs{INVERS_URL} ne "") && index($extName, "Unknown") > -1) { # Add invers search URL
    my $searchUrl = $cfgHashs{INVERS_URL};
    my $numberCleand = $number;
    $numberCleand =~ s/ //g;
    $numberCleand=addCountryArea($numberCleand); # z.B. Ortsvorwahl fehlt, falls nicht mitgewählt
    $searchUrl =~ s/\{number\}/$numberCleand/;
    $extName = "$extName <a target='_blank' href='" . $searchUrl . "'><img src='images/search.png', width='$cfgHashs{SIZE_ICON}', height='$cfgHashs{SIZE_ICON}'></a>";
    if (( $number =~ /^0[1-9].*/ ) && ($cfgHashs{MAP_URL} ne "")) { # not 00.. and MAP_URL defined
      # $vaz ?????????????????????????????????
      # add an link to lookup the map for the area code
      my @numParts = (split / /, $number, 2);
      print "appendLinks2extName() Number splitted #numParts=$#numParts, numParts[1]=$numParts[1] \n";      
      if (($#numParts == 1) && ($numParts[0] ne "0800") && ($numParts[0] ne "0700") && ($numParts[0] =~ /^1.*/ )) {
        my $mapUrl=$cfgHashs{MAP_URL};
        $mapUrl =~ s/\{number\}/$numParts[0]/;
        print "Map-Area: $numParts[0], mapUrl=$mapUrl\n";
        $number="<a target='_blank' href='$mapUrl'>$numParts[0]</a> $numParts[1]";
        }
      print "Lookup-Number: $number\n";
      }
    }
  else {print "  not unknown or no searchUrl\n";}  
  if ( $eMail ne "") {
    $extName = "$extName <a href='mailto:${eMail}'><img src='images/eMail.png', width='$cfgHashs{SIZE_ICON}', height='$cfgHashs{SIZE_ICON}'></a>";
    }
  else {print "  no eMail\n";}
    if ( $whatsApp ne "") {
    # https://stackoverflow.com/questions/30344476/web-link-to-specific-whatsapp-contact
    # Option with predefined Text: https://wa.me/552196312XXXX?text=[message-url-encoded]
    $whatsApp =~ s/^$vaz//; # remove leading the 00 (substitue 00 by %2B works also). Must start with international code (e.g. 49 for Germany)
    $extName = "$extName <a target='_blank' href='https://wa.me/$whatsApp'><img src='images/whatsApp.png', width='$cfgHashs{SIZE_ICON}', height='$cfgHashs{SIZE_ICON}'></a>";
    }
  print "expanded Name: $extName\n";
  return ($extName, $number);  
  }


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
  doExecLog(4, "sendToCcu(): curl res=$res, ret='$ret', IP_CCU=$cfgHashs{IP_CCU}, CCU_USER=$cfgHashs{CCU_USER}, Data=$curlDataI");
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
  $scriptFilePathName =~ s/^\s+|\s+$//g; # trim ( \s* = multiple Whitespace )
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

