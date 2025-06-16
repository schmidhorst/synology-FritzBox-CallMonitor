#!/bin/bash
# Filename: calls.cgi - coded in utf-8
# Copyright (C) 2024...2025 by Horst Schmid
#             License GNU GPLv3
#   https://www.gnu.org/licenses/gpl-3.0.html

###### This calls.cgi is in the config file configured as "url": "/webman/3rdparty/<appName>/index.cgi"
# /usr/syno/synoman/webman/3rdparty/<app> is linked to /volumeX/@apptemp/<app>/ui
# and /var/packages/<app>/target/ui is the same folder

# for https://www.shellcheck.net/
# shellcheck disable=SC1090


printFormatedCallLine() {
  local line=$1
  local fontTag=$2
  # local bUrlEncode=$3 # would need printf ... | jq -cRr @uri
  if [[ -n "$fontTag" ]]; then
    # logInfoNoEcho 4 "printFormatedCallLine with fontTag"
    fontEndTag="</font>"
  fi
  mapfile -d ';' -t a <<< "$line"
  logInfoNoEcho 7 "found a[0]='${a[0],,}', requested which='${which,,}'"
  # a[0]=which, a[1]=Date, a[2]=Number, a[3]=Name, a[4]=eMail, a[5]=Book, a[6]=Line, a[7]=Extension, a[8]=Duration
  if [[ "${a[0],,}" == "${which,,}" ]] || [[ "${which,,}" == "all" ]]; then # filter the requeted typ (IN, OUT, ...) of lines
    if [[ "${a[3]}" =~ "Unknown from" ]];then # Translate to the language prefered by browser
      a[3]=${a[3]/Unknown from/"$unknownFrom"}
    else
      a[3]=${a[3]/Unknown/"$unknown"}
    fi
    whichLower=${a[0],,} 
    ((cnt1++))
    printf "<tr><td ${COLW[0]}><img src='%s', width='%s', height='%s'></td>" "images/${whichLower}Call.png" "$SIZE_ICON" "$SIZE_ICON"
    for i in "${!a[@]}"; do
      if [[ "$i" -gt "0" ]]; then
        printf "<td %s>${fontTag}%s${fontEndTag}</td>" "${COLW[i]}" "${a[$i]}"
      fi  
    done # for
    echo "</tr>"
  else
    logInfoNoEcho 7 "line ignored, a[0]=${a[0],,}, requested which='${which,,}'"
  fi # which or ALL
  }


# Initiate system
# --------------------------------------------------------------
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin
LC_CTYPE=en_US.utf8
bDebug=0 # 0= do cgiLogin, evaluateCgiLogin; 1= skip cgiLogin, evaluateCgiLogin
actualCallsFontColor="DarkRed";
declare -A get # associative array for parameters (POST, GET)

if [[ -z "$SCRIPT_NAME" ]]; then  # direct start in debug run
  SCRIPT_NAME="/webman/3rdparty/callmonitor/calls.cgi"
  bDebug=1
  echo "###### calls.cgi executed in debug mode!!  ######"
  get["action"]="delCalls"
fi
# ${BASH_SOURCE[0]}=/usr/syno/synoman/webman/3rdparty/<appName>/calls.cgi
app_link=${SCRIPT_NAME%/*} # "/webman/3rdparty/<appName>"
app_name=${app_link##*/} # "<appName>"
# DOCUMENT_URI=/webman/3rdparty/<appName>/calls.cgi
# PWD=/volume1/@appstore/<appName>/ui
user=$(whoami) # EnvVar $USER may be not well set, user is '<appName>'
# REQUEST_URI=/webman/3rdparty/<appName>/calls.cgi
# SCRIPT_FILENAME=/usr/syno/synoman/webman/3rdparty/<appName>/calls.cgi

if [[ -w "/var/log/packages/${app_name}.log" ]]; then 
  LOG="/var/log/packages/${app_name}.log"
elif [[ -w "/var/tmp/${app_name}.log" ]]; then
  LOG="/var/tmp/${app_name}.log"  # no permission if default -rw-r--r-- root:root was not changed
fi
DTFMT="+%Y-%m-%d %H:%M:%S" # may be overwritten by parse_hlp
# $SHELL' is here "/sbin/nologin"
msg1="App '$app_name' file '$(basename "${BASH_SOURCE[0]}")' started as user '$user' with parameters '$QUERY_STRING' and with logging to '$LOG' ..."
ah="/volume*/@appstore/$app_name/ui"
app_home=$(find $ah -maxdepth 0 -type d) # Attention: find is not working with quoted path!!
# env >> $LOG"
# Load urlencode and urldecode, logInfoNoEcho, ... function from ../modules/parse_hlp.sh:
if [ -f "${app_home}/modules/parse_hlp.sh" ]; then
  # shellcheck disable=SC1091
  source "${app_home}/modules/parse_hlp.sh" # includes reading of config file (source)
  res=$?
  # echo "$(date "$DTFMT"): $msg1<br>Loading ${app_home}/modules/parse_hlp.sh with functions urlencode() and urldecode() done with result $res" >> "$LOG"
  if [[ "$res" -gt 1 ]]; then
    echo "### Loading ${app_home}/modules/parse_hlp.sh failed!! res='$res' ###" >> "$LOG"
    exit
  else
    msg1="$msg1, ${app_home}/modules/parse_hlp.sh done"
    # BACKGROUND_COLOR, BORDER_WIDTH, CELLPADDING, COLW_ICON, COLW_DATE, COLW_NAME, COLW_BOOK, COLW_SIP, COLW_NEBENSTELLE, COLW_DURATION, SIZE_ICON
    # shellcheck disable=SC2206
    COLW0=($COLW_ICON $COLW_DATE $COLW_NAME $COLW_BOOK $COLW_SIP $COLW_NEBENSTELLE $COLW_DURATION) # "AUTO" or e.g. "20"
    COLW=()
    for i in "${!COLW0[@]}"; do
      logInfoNoEcho 7 "Column width $i='${COLW0[$i]}'"    
      if [[ "${COLW0[$i]}" == "AUTO" ]]; then
        COLW[i]=""
      else
        COLW[i]=" width:'${COLW0[$i]}'"
      fi  
    done
    backGround=""
    if [[ -n "$BACKGROUND_COLOR" ]];then
      backGround=" style='background-color:#${BACKGROUND_COLOR};'"
    fi
  fi
else
  echo "$(date "$DTFMT"): $msg1<br>Failed to find ${app_home}/modules/parse_hlp.sh with functions urlencode() and urldecode() skipped" >> "$LOG"
  # echo -e "$msg1\nFailed to find ${app_home}/modules/parse_hlp.sh"
  # in journal this echo is causing "upstream sent invalid header: "App\x20..." while reading response header"
  # exit
fi
logInfoNoEcho 8 "$msg1"
if [[ "$app_name" == "ui" ]]; then
  logInfoNoEcho 1 "wrong app_name='$app_name'"
fi

#appCfgDataPath=$(find /volume*/@appdata/${app_name} -maxdepth 0 -type d)
appCfgDataPath="/var/packages/${app_name}/var"
# Evaluate app authentication
# To evaluate the SynoToken, change REQUEST_METHOD to GET
# Read out and check the login authorization  ( login.cgi )
if [[ "$bDebug" -eq 0 ]]; then
  cgiLogin # see parse_hlp.sh, sets $syno_login, $syno_token, $syno_user, $is_admin
  # this may fail with permission denied and result 3
  ret=$?
  if [[ "$ret" -ne "0" ]]; then
    echo "$(date "$DTFMT"): $(basename "${BASH_SOURCE[0]}"), calling cgiLogin failed, ret='$ret' " >> "$LOG"
    # exit
  else
    logInfoNoEcho 8 "cgiLogin done successfully"
  fi
else
  logInfoNoEcho 4 "Due to debug mode login skipped"
fi

# get the installed version of the package for later comparison to latest version on github:
# shellcheck disable=SC2002
local_version=$(cat "/var/packages/${app_name}/INFO" | grep ^version | cut -d '"' -f2)

# Workaround if language loading failed:
displaynameINFO="$app_name" # "CallMonitor"
btnShowLicence="Licence"
# shellcheck disable=SC2034
btnShowLog="Action Log"
# shellcheck disable=SC2034
btnDownload="All Calls"
# shellcheck disable=SC2034
btnDelLog="Out Calls"
# shellcheck disable=SC2034
btnRefresh="In Calls"
btnShowSettings="Settings"

if [ -x "${app_home}/modules/parse_language.sh" ]; then
  # shellcheck disable=SC1091
  source "${app_home}/modules/parse_language.sh" "${syno_user}"
  res=$?
  logInfoNoEcho 8 "Loading ${app_home}/modules/parse_language.sh done with result $res"
else
  logInfoNoEcho 1 "Loading ${app_home}/modules/parse_language.sh failed"
fi
# ${used_lang} is now setup, e.g. enu

if [ -x "${app_home}/modules/cgi_hlp.sh" ]; then
  # shellcheck disable=SC1091
  source "${app_home}/modules/cgi_hlp.sh"
else
  logInfoNoEcho 2 "Loading ${app_home}/modules/cgi_hlp.sh failed"
fi

# Resetting access permissions
unset syno_login rar_data syno_privilege syno_token user_exist is_authenticated

# Evaluate app authentication
if [[ "$bDebug" -eq 0 ]]; then
  evaluateCgiLogin # in parse_hlp.sh
  ret=$?
  if [[ "$ret" -ne "0" ]]; then
    logInfoNoEcho 1 "$(basename "${BASH_SOURCE[0]}"), execution of evaluateCgiLogin failed, ret='$ret'"
    exit
  fi
else
  echo "Due to debug mode access check skipped"
  # is_admin="yes"
fi

# Set variables to "readonly" for protection or empty contents
unset syno_login rar_data syno_privilege
# readonly syno_token syno_user user_exist is_admin # is_authenticated
readonly syno_user is_admin # user_exist syno_token is_authenticated
# shellcheck disable=SC2154
logInfoNoEcho 7 "used_lang='$used_lang'"

licenceFile="licence_${used_lang}.html"
if [[ ! -f "licence_${used_lang}.html" ]]; then
  licenceFile="licence_enu.html"
  logInfoNoEcho 5 "Licence: Fallback to ENU"
fi

if [ ! -d "${appCfgDataPath}" ]; then
  logInfoNoEcho 1 "... terminating $(basename "${BASH_SOURCE[0]}") as app home folder '$appCfgDataPath' not found!"
  echo "$(date "$DTFMT"): ls -l /:" >> "$LOG"
  ls -l / >> "$LOG"
  exit
fi

# Set environment variables
# --------------------------------------------------------------
# Set up folder for temporary data:
app_temp="${app_home}/temp" # /volume*/@appstore/${app_name}/ui/temp
#  or /volume*/@apptemp/$app_name ??
if [ ! -d "${app_temp}" ]; then
  # shellcheck disable=SC2174
  mkdir -p -m 755 "${app_temp}"
fi
# result="${app_temp}/result.txt"

# Evaluate POST and GET requests and cache them in files
  # get_keyvalue="/bin/get_key_value"
# get_request="$app_temp/get_request.txt"

# Processing GET/POST request variables
# CONTENT_LENGTH: CGI meta variable https://stackoverflow.com/questions/59839481/what-is-the-content-length-varaible-of-a-cgi

SCRIPT_EXEC_LOG="$appCfgDataPath/execLog"
logInfoNoEcho 7 "logfile SCRIPT_EXEC_LOG='$SCRIPT_EXEC_LOG', later optionally '$appCfgDataPath/detailLog'"
logfile="$SCRIPT_EXEC_LOG" # default, later optionally set to "$appCfgDataPath/detailLog"

# Analyze incoming POST requests and process them to ${get[key]}="$value" variables
cgiDataEval # parse_hlp.sh, setup associative array get[] from the request (POST and GET)

versionUpdateHint=""
githubRawInfoUrl="https://raw.githubusercontent.com/schmidhorst/synology-FritzBox-CallMonitor/main/INFO.sh" #patched to distributor_url from INFO.sh
 # above line will be patched from INFO.sh and is used to check for a newer version
if [[ -n "$githubRawInfoUrl" ]]; then
  git_version=$(wget --timeout=30 --tries=1 -q -O- "$githubRawInfoUrl" | grep ^version | cut -d '"' -f2)
  logInfoNoEcho 6 "local_version='$local_version', git_version='$git_version'"
  if [ -n "${git_version}" ] && [ -n "${local_version}" ]; then
    if dpkg --compare-versions "${git_version}" gt "${local_version}"; then  # There is a newer Version on the Server:
    # if dpkg --compare-versions ${git_version} lt ${local_version}; then # for debugging
      # shellcheck disable=SC2154
      vh=$update_available
      versionUpdateHint='<p style="text-align:center">'${vh}' <a href="https://github.com/schmidhorst/synology-'${app_name}'/releases" target="_blank">'${git_version}'</a></p>'
    fi
  fi
fi

if [[ "$bDebug" -eq 1 ]]; then
  logfile="/var/tmp/$app_name"  # optionally to debug behaviour for the debug log instead of action log
fi
callsFile="$appCfgDataPath/calls.txt"

if [[ -n "${get[action]}" ]]; then
  val="${get[action]}"
  logInfoNoEcho 7 "action=$val"  
  if [[ "$val" == "showDetailLog" ]] || [[ "$val" == "delDetailLog" ]] || [[ "$val" == "reloadDetailLog" ]] || [[ "$val" == "downloadDetailLog" ]] || [[ "$val" == "chgDetailLogLevel" ]] || [[ "$val" == "SupportEMail" ]] || [[ "$bDebug" -eq 1 ]]; then
    # logfile="/var/tmp/$app_name" # this is not working ! But LOG="/var/tmp/${app_name}.log" works !????
    logfile="$appCfgDataPath/detailLog"  # Link to /var/tmp/$app_name.log
  fi

  if [[ "$val" == "event" ]]; then # Server received a request to setup event channel
    logInfoNoEcho 3 "starting a loop to wait for /dev/shm/$app_name.Actual and send event"
    # printf "Content-type: text/event-stream; charset=utf-8\n" # initiate
    which="all"
    size=0
    dt=""
    fontTag=""
    if [[ "$actualCallsFontColor" != "" ]]; then
      fontTag="<font color='$actualCallsFontColor'>"
    fi

    while true; do # wait for an active call
      sleep 1
      if [ -f "/dev/shm/$app_name.Actual" ]; then
        size2=$(stat --format=%s "/dev/shm/$app_name.Actual") # %s = Total size, in bytes 
        dt2=$(stat --format=%y "/dev/shm/$app_name.Actual") # %y – Time of last data modification 
        if [ "$size2" -ne "0" ] && [ "$dt2" != "$dt" ]; then # call status changed
          logInfoNoEcho 3 "new active call(s), size1=$size, size2=$size2, $dt2"
          size=$size2
          # activeCall=1   
          printf "Content-type: text/event-stream; charset=utf-8\n\n"
          # printf "data: %s new Call!\n" "$(date "$DTFMT")"
          cnt0=0
          printf "data: " 
          while IFS=$'\n' read -r line; do # read all items from logfile
            # letzte Zeile der Datei muß auch noch ein \n enthalten, sonst wird sie ignoriert!
            ((cnt0++))
            logInfoNoEcho 7 "data Line ${cnt0} send: $line"
            # printf "data: %s\n\n" "$line"
            printf "data: "
            printFormatedCallLine "$line" "$fontTag" # no URI-Encoding required!
            printf "\n\n"
          done < "/dev/shm/$app_name.Actual" # lines of file
          printf "\n\n"
          logInfoNoEcho 7 "$cnt0 lines send"
        elif [ "$size2" -eq "0" ] && [ "$size" -ne "0" ]; then # all calls terminated
          size=0
          # printf "Content-type: text/event-stream; charset=utf-8\n\n"
          # printf "data: %s reload!!\n" "$(date "$DTFMT")"
          printf "data: %s call terminated, reload!!\n\n" "$(date "$DTFMT")"
          logInfoNoEcho 3 "all calls terminated"
          sleep 1
          exit
        fi # size
        dt=$dt2
      else
        logInfoNoEcho 3 "File $/dev/shm/$app_name.Actual not existing"
      fi
    done
    logInfoNoEcho 3 "event loop terminated"
    exit # Browser shoul open page newly now
  else
    which=${get[action],,}
  fi # if else $val==event

  if [[ "$val" == "delCalls" ]] && [[ "$is_admin" == "yes" ]]; then    
    rm "${callsFile}"* # including rotated files
    logInfoNoEcho 3 "List of calls deleted by $user"
    which="all" # ahow again the ALL listing, which is now empty
  fi
  if [[ "$val" == "delSimpleLog" ]] || [[ "$val" == "delDetailLog" ]]; then
    rm "$logfile"*
    logInfoNoEcho 4 "Old content of '$logfile*' removed"
  fi

  if [[ "$val" == "SupportEMail" ]]; then # net yet working, not yet used!
    # https://community.synology.com/enu/forum/10/post/135979

    # not yet working:
    if [[ "${REQUEST_METHOD}" == "GET" ]]; then
      OLD_REQUEST_METHOD="GET"
      REQUEST_METHOD="POST"
    fi

    echo "Content-type: text/html; charset=utf-8"
    echo
    echo "<!doctype html><html lang=\"${SYNO2ISO[${used_lang}]}\"><head>"
    echo '<meta charset="utf-8" /><link rel="shortcut icon" href="images/icon_32.png" type="image/x-icon" />
          <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />
          <link rel="stylesheet" type="text/css" href="dsm3.css"/></head><body>'
    echo "<p>Please describe your problem in Englisch or German language in the generated E-Mail</p>"
    echo "<p><a target='_blank' rel='noopener noreferrer' href='mailto:synoapps@schmidhorst.de?subject=$app_name"
    #### eMail should be defined and fetched from INFO file
    echo "Not yet working!"
    # urlencode "$(cat "$logfile")"
    #echo ""
    # urlencode "$(env)"
    #echo ""
    # urlencode "$(cat "$SCRIPT_EXEC_LOG")"
    echo '">Generate Email</a></p></body>'

    # Set REQUEST_METHOD back to GET again:
    if [[ "${OLD_REQUEST_METHOD}" == "POST" ]]; then
      REQUEST_METHOD="GET"
      unset OLD_REQUEST_METHOD
    fi
    exit
  fi

  if [[ "$val" == "downloadSimpleLog" ]] || [[ "$val" == "downloadDetailLog" ]]; then
    # shellcheck disable=SC2154
    logInfoNoEcho 4 "Download content of '$logfile' requested, disposition='$disposition'"
    echo "Content-type: text/plain; charset=utf-8"
    fnX=$(basename "$logfile");
    echo "Content-Disposition: attachment; filename=${fnX}.txt"
    echo
    # echo "<!doctype html>"
    cat "$logfile"
    if [[ "$val" == "downloadDetailLog" ]]; then
      echo -e "\n"
      env || printenv
      echo ""
      # lets append the content of $SCRIPT_EXEC_LOG for full debug info:
      cat "$SCRIPT_EXEC_LOG"
    fi
    exit
  fi # if [[ "$val" == "downloadSimpleLog" ]] || [[ "$val" == "downloadDetailLog" ]]

  if [[ "$val" == "reloadSimpleLog" ]] || [[ "$val" == "reloadDetailLog" ]]; then
    logInfoNoEcho 7 "Page reload"
    # script to scroll to bottom of list:
    myScript="<script>
    "
    myScript="${myScript} window.onload=function(){ window.scrollTo(0, document.body.scrollHeight);}"  # scroll to bottom
    myScript="$myScript
     </script>
     "
  fi # reload
else
  logInfoNoEcho 8 "no get[action]"
fi # action

# Inclusion of the temporarily stored GET/POST requests ( key="value" ) as well as the user settings
# [ -f "${get_request}" ] && source "${get_request}"
# [ -f "${post_request}" ] && source "${post_request}"

# Layout output
# --------------------------------------------------------------
# shellcheck disable=SC2046
if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ]; then
  if [[ "$which" == "" ]]; then
    which="all"
    logInfoNoEcho 8 "'which' was undefined, set to 'ALL'"
  else
    logInfoNoEcho 8 "'which'='$which'"
  fi
  metaRfsh=""
  if [[ "$AUTOREFRESH_S" != "0" ]]; then  
    metaRfsh="<meta http-equiv=refresh content='$AUTOREFRESH_S'>"
  fi

  echo "Content-type: text/html; charset=utf-8"
  echo ""
  echo "
  <!doctype html>
  <html lang=\"${SYNO2ISO[${used_lang}]}\">
    <head>"
  echo '<meta charset="utf-8" />'
  echo '
      <link rel="shortcut icon" href="images/icon_32.png" type="image/x-icon" />
      <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />
      <link rel="stylesheet" type="text/css" href="dsm3.css"/>'
  echo "$metaRfsh"
  echo "<script src='calls.js'></script>"
  echo "$myScript"
  echo '</head>
    <body onload="myLoad()" onresize="setBoxHeight()">
      <header>'
  echo "$versionUpdateHint"
  # Load page content
  # --------------------------------------------------------------
  if [[ "$which" != "all" ]]; then
    # shellcheck disable=SC2154
    echo "<button onclick=\"location.href='calls.cgi?action=ALL'\" type=\"button\">$btnAllCalls</button> "
  fi
  if [[ "$which" != "out" ]]; then
    # shellcheck disable=SC2154
    echo "<button onclick=\"location.href='calls.cgi?action=OUT'\" type=\"button\">$btnOutCalls</button> "
  fi  
  if [[ "$which" != "in" ]]; then
    # shellcheck disable=SC2154
    echo "<button onclick=\"location.href='calls.cgi?action=IN'\" type=\"button\">$btnInCalls</button> "
  fi  
  if [[ "$which" != "missed" ]]; then
    # shellcheck disable=SC2154
    echo "<button onclick=\"location.href='calls.cgi?action=MISSED'\" type=\"button\">$btnMissedCalls</button> "
  fi
  # shellcheck disable=SC2154
  echo "<button onclick=\"location.href='help/${used_lang}/index.html'\" type=\"button\">$btnHelp</button> "
  # HTTP GET and POST requests

  echo "<button onclick=\"location.href='settings.cgi'\" type=\"button\">${btnShowSettings}</button> "
  echo "<button onclick=\"location.href='$licenceFile'\" type=\"button\">${btnShowLicence}</button> "
# https://stackoverflow.com/questions/21168521/table-fixed-header-and-scrollable-body
# https://www.quackit.com/html/codes/html_scroll_box.cfm
# https://www.w3schools.com/jsref/prop_win_innerheight.asp
  wh1=${which^} # in ==> In, out ==> Out, ...
  varTitleExt="btn${wh1}Calls"
  titleExt=${!varTitleExt}
  logInfoNoEcho 7 "varTitleExt=$varTitleExt, titleExt=$titleExt"

  echo "<p><strong>$displaynameINFO: $titleExt</strong></p>"
  echo "</header>"
  echo "<div id='mybox' style='height:360px;width:100%;overflow:auto;'>"        
  echo "<table id='callsList' border='$BORDER_WIDTH' cellpadding='$CELLPADDING' $backGround><tbody>"
  # shellcheck disable=SC2154
  echo "<tr><th></th><th>${headerDate}</th><th>${headerNumber}</th><th>${headerName}</th><th>${headerBook}</th><th>${headerLine}</th><th>${headerExtension}</th><th>${headerDuration}</th></tr>"
  #            dir                 externeNr        extern         

  cnt1=0 # Anrufe je nach Auswahl IN, OUT, MISSED, ALL
  cnt0=0 # Anrufe insges.
  if [[ -r "$callsFile" ]] || [ -r "${callsFile}.1" ]; then
    logInfoNoEcho 7 "Calls file $callsFile found"
    # shellcheck disable=SC2154
    logInfoNoEcho 7 "Lng-Specific 'unknown' (from lang.txt) is '$unknown'"
    # linkedFileSize "${callsFile}" # variable filesize_Bytes is set
    # logInfoNoEcho 8 "Found ${callsFile} with $filesize_Bytes Bytes"
    filesArray=("${callsFile}.1" "$callsFile" "/dev/shm/$app_name.Actual")
    for file in "${filesArray[@]}"; do
      fontTag=""
      # fontEndTag=""
      # if [[ "$file" == "/dev/shm/$app_name.Actual" ]] && [[ "$actualCallsFontColor" != "" ]]; then
      #  fontTag="<font color='$actualCallsFontColor'>"
      #  fontEndTag="</font>"
      # fi
      if [[ -f "$file" ]]; then # logrotation file ${callsFile}.1 may not exist
        while IFS=$'\n' read -r line; do # read all items from logfile
          ((cnt0++))
          # logInfoNoEcho 8 "Line ${cnt0}: $line"
          printFormatedCallLine "$line" "" # no FontTag
        done < "$file" # lines of file
      fi
    done # for
  else # $callsFile nicht lesbar
    if [[ -f "$callsFile" ]]; then
      logInfoNoEcho 1 "'$callsFile' not readable for $user!"
    else
      logInfoNoEcho 7 "'$callsFile' not found!"
    fi
  fi # if [[ -f "$logfile" ]] else
  if [[ "$cnt1" -eq "0" ]]; then
    noCall="no${wh1}Call"
    logInfoNoEcho 5 "${noCall}=${!noCall}"
    echo "<td colspan='8'>${!noCall}</td>" # fetch e.g. $noInCall from lang.txt
  else
    logInfoNoEcho 8 "$cnt1 Entries from $cnt0 total added"
  fi
  # echo '<div id="active"></div>' # not working, div element is put to before table
  echo '</tbody></table></div>'
  # https://talent500.com/blog/server-sent-events-real-time-updates/
  # https://developer.mozilla.org/de/docs/Web/API/EventSource : Statt 'new EventSource('/events');' 'new EventSource("sse.php");'
  # echo "<div id='time'>time</div>"
  logInfoNoEcho 8 "Table with call entries done, footer ..."
  logInfoNoEcho 8 "cnt0=$cnt0, action=${get[action]}, admin=$is_admin"
  allowDelete=false
  if [[ "${get[action]}" == "ALL" ]] || [[ "${get[action]}" == "ALL" ]]; then
    allowDelete=true
  fi
  echo "<p>"
  if [[ cnt0 -gt 0 ]] && [[ "$allowDelete" ]] && [[ "$is_admin" == "yes" ]]; then
    # shellcheck disable=SC2154
    echo "<button onclick=\"location.href='calls.cgi?action=delCalls'\" type=\"button\">${btnDelCalls}</button> "
  fi # if [[ "$logfile" == "$SCRIPT_EXEC_LOG" ]] else
  if [[ "$is_admin" == "yes" ]]; then
    # shellcheck disable=SC2154
    echo "<button onclick=\"location.href='index.cgi'\" type=\"button\">${btnShowLog}</button>"
  fi # if [[ "$logfile" == "$SCRIPT_EXEC_LOG" ]] else
  echo "</p>
  </body> </html>"
fi # if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ]

logInfoNoEcho 5 "... $(basename "${BASH_SOURCE[0]}") done"
exit

