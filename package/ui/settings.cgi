#!/bin/bash
# Filename: settings.cgi - coded in utf-8
#    taken from
#  DSM7DemoSPK (https://github.com/toafez/DSM7DemoSPK)
#        Copyright (C) 2022 by Tommes
# Member of the German Synology Community Forum

# Adopted to need of Autorun and CallMonitor by Horst Schmid
#      Copyright (C) 2022...2024 by Horst Schmid

#             License GNU GPLv3
#   https://www.gnu.org/licenses/gpl-3.0.html

# /usr/syno/synoman/webman/3rdparty/<app> is linked to /volumeX/@apptemp/<app>/ui
# and /var/packages/<app>/target/ui is the same folder

# for https://www.shellcheck.net/
# shellcheck disable=SC1090

# Initiate system
# --------------------------------------------------------------
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin
bDebug="0" # 0= do cgiLogin, evaluateCgiLogin; 1= skip cgiLogin, evaluateCgiLogin
# SCRIPT_NAME=/webman/3rdparty/<appName>/settings.cgi
if [[ -z "$SCRIPT_NAME" ]]; then  # direct start in debug run
  SCRIPT_NAME="/webman/3rdparty/callmonitor/settings.cgi"
  bDebug=1
  echo "###### settings.cgi executed in debug mode!!  ######"
fi
# $0=/usr/syno/synoman/webman/3rdparty/<appName>/settings.cgi
app_link=${SCRIPT_NAME%/*} # "/webman/3rdparty/<appName>"
app_name=${app_link##*/} # "<appName>"
# DOCUMENT_URI=/webman/3rdparty/<appName>/settings.cgi
# PWD=/volume1/@appstore/<appName>/ui
user=$(whoami) # EnvVar $USER may be not well set, user is '<appName>'
# REQUEST_URI=/webman/3rdparty/<appName>/settings.cgi
# SCRIPT_FILENAME=/usr/syno/synoman/webman/3rdparty/<appName>/settings.cgi
display_name="Tool to monitor phone calls from FritzBox" # used as title of Page

if [[ -w "/var/log/packages/${app_name}.log" ]]; then
  LOG="/var/log/packages/${app_name}.log"
elif [[ -w "/var/tmp/${app_name}.log" ]]; then
  LOG="/var/tmp/${app_name}.log"  # no permission if default -rw-r--r-- root:root was not changed
fi

#line="$(grep -i "DEBUGLOG=" "/var/packages/$app_name/var/config")"
#if [[ -n "$line" ]]; then # entry available
#  LOG="$(echo "$line" | sed -e 's/^DEBUGLOG="//' -e 's/"$//')"
#fi
DTFMT="+%Y-%m-%d %H:%M:%S" # may be overwritten by parse_hlp
msg1="App '$app_name' file '$(basename "${BASH_SOURCE[0]}")' started as user '$user' with parameters '$QUERY_STRING' ..."
app_home=$(find /volume*/@appstore/"$app_name/ui" -maxdepth 0 -type d)

# Load urlencode and urldecode, logInfoNoEcho, ... function from ../modules/parse_hlp.sh:
if [ -f "${app_home}/modules/parse_hlp.sh" ]; then
  source "${app_home}/modules/parse_hlp.sh" # includes reading of LOGLEVEL from config file
  res=$?
  # echo "$(date "$DTFMT"): $msg1<br>Loading ${app_home}/modules/parse_hlp.sh with functions urlencode() and urldecode() done with result $res" >> "$LOG"
  if [[ "$res" -gt 1 ]]; then
    echo "### Loading ${app_home}/modules/parse_hlp.sh failed!! res='$res' ###" >> "$LOG"
    exit
  fi
else
  echo "$(date "$DTFMT"): $msg1<br>Failed to find ${app_home}/modules/parse_hlp.sh with functions urlencode() and urldecode() skipped" >> "$LOG"
  echo -e "$msg1\nFailed to find ${app_home}/modules/parse_hlp.sh"
  exit
fi
logInfoNoEcho 8 "$msg1"
if [[ "$app_name" == "ui" ]]; then
  logInfoNoEcho 1 "wrong app_name='$app_name'"
fi

# Evaluate app authentication
# To evaluate the SynoToken, change REQUEST_METHOD to GET
# Read out and check the login authorization  ( login.cgi )
if [[ "$bDebug" -eq 0 ]]; then
  cgiLogin # see parse_hlp.sh, sets $syno_login, $syno_token, $syno_user, $is_admin
  # this may fail with permission denied and result 3
  ret=$?
  if [[ "$ret" -ne "0" ]]; then
    echo "$(date "$DTFMT"): $(basename "${BASH_SOURCE[0]}"), calling cgiLogin failed, ret='$ret' " >> "$LOG"
    exit
  fi
else
  echo "Due to debug mode login skipped"
fi

if [ -x "${app_home}/modules/parse_language.sh" ]; then
  # res="$(source "${app_home}/modules/parse_language.sh" "${syno_user}" 2>&1)" possible change of used_lang in subshell will be lost!
  source "${app_home}/modules/parse_language.sh" "${syno_user}"
  ret=$?
  if [[ "$ret" -ne "0" ]];then
    # logInfoNoEcho 1 "Loading ${app_home}/modules/parse_language.sh done with result $ret: ${res//$'\n'/<br />}
    logInfoNoEcho 1 "Loading ${app_home}/modules/parse_language.sh done with result $ret"
  else
    logInfoNoEcho 8 "Loading ${app_home}/modules/parse_language.sh done with result $ret"
  fi
  # || exit
else
  logInfoNoEcho 1 "Not executable: ${app_home}/modules/parse_language.sh"
  exit
fi

# Resetting access permissions
unset syno_login rar_data syno_privilege syno_token user_exist is_authenticated
declare -A get # associative array for parameters (POST, GET)

# Evaluate app authentication
if [[ "$bDebug" -eq 0 ]]; then
  evaluateCgiLogin # in parse_hlp.sh
  ret=$?
  if [[ "$ret" -ne "0" ]]; then
    logInfoNoEcho 1 "Execution of evaluateCgiLogin failed, ret='$ret'"
    exit
  fi
else
  echo "Due to debug mode access check skipped"
  is_admin="yes"
fi

# Set variables to "readonly" for protection or empty contents
unset syno_login rar_data syno_privilege
# shellcheck disable=SC2034
readonly syno_token syno_user user_exist is_admin # is_authenticated

licenceFile="licence_${used_lang}.html"
if [[ ! -f "licence_${used_lang}.html" ]]; then
  licenceFile="licence_enu.html"
fi

if [ "$is_admin" != "yes" ]; then
  echo "Content-type: text/html"
  echo
  echo "<!doctype html><html lang='${SYNO2ISO[${used_lang}]}'>"
  echo "<HEAD><TITLE>$app_name: ${LoginRequired}</TITLE>"
  echo "<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>"
  echo "</HEAD><BODY>${PleaseLogin}<br/>"
  echo "<button onclick=\"location.href='$licenceFile'\" type=\"button\">${btnShowLicence}</button> "
  echo "<p style=\"margin-left:22px; line-height: 16px;\"><form><input type=\"button\" value=\"Zurück Back\" onclick=\"history.back()\"></form></p>"

  echo "<br/></BODY></HTML>"
  logInfoNoEcho 3 "Admin Login required!"
  echo "Admin Login required!"
  exit 0
fi

#appCfgDataPath=$(find /volume*/@appdata/${app_name} -maxdepth 0 -type d)
appCfgDataPath="/var/packages/${app_name}/var"
if [ ! -d "${appCfgDataPath}" ]; then
  logInfoNoEcho 1 "... terminating $(basename "${BASH_SOURCE[0]}") as app home folder '$appCfgDataPath' not found!"
  echo "$(date "$DTFMT"): ls -l /:" >> "$LOG"
  ls -l / >> "$LOG"
  exit
fi

# Generate the text with the actual settings values and the language specific descriptions:
st=$(echo "$settingsTitle")  # = eval the $app_name in the $settingsTitle
ledResetPossiblyRequired=0
securityWarningDone=0
syslog=""
tbDav=""
tbXml=""
tbBookName=""
cw=""
while read line; do # read all settings from config file
  itemName=${line%%=*}
  # eval "$line" # not secure, code injection may be possible
  declare "${line%%=*}"="$(echo "${line#*=}" | sed -e 's/^"//' -e 's/"$//')" # more secure
  settingDescrName="setting$itemName"
  if [[ "$itemName" =~ ^TELBOOK_DAV.* ]];then # gruppierte Einträge
    tbDav="$tbDav<br>$itemName='${!itemName}'"
  elif [[ "$itemName" =~ ^TELBOOK_XML.* ]];then
    tbXml="$tbXml<br>$itemName='${!itemName}'"
  elif [[ "$itemName" =~ ^COLW_.* ]];then
    cw="$cw<br>$itemName='${!itemName}'"
  elif [[ "$itemName" =~ ^BOOKNAME_.* ]]; then
    tbBookName="$tbBookName<br>$itemName='${!itemName}'"
  elif [[ "$itemName" =~ ^LICENSE_ACCEPTED.* ]]; then
    continue # ignore
  else
    settings="${settings}$itemName='${!itemName}'<br/>" # itemName and itemValue
    if [[ -n "${!settingDescrName}" ]]; then # in lang.txt there is an explanation 
      settings="${settings}<p style=\"margin-left:30px;\">${!settingDescrName}<br/></p>"
    fi
  fi
  # echo "  line='$line', itemName='$itemName', value='${!itemName}'" >> "$LOG"
done < "$appCfgDataPath/config" # Works well even if last line has no \n!

if [[ "$tbDav" != "" ]]; then
  settings="${settings}${tbDav#*<br>}<br/>"
  if [[ -n "${settingTELBOOK_DAV1}" ]]; then # in lang.txt there is an explanation 
    settings="${settings}<p style=\"margin-left:30px;\">${settingTELBOOK_DAV1}<br/></p>"
  fi  
fi
if [[ "$tbXml" != "" ]]; then
  settings="${settings}${tbXml#*<br>}<br/>"
  if [[ -n "${settingTELBOOK_XML1}" ]]; then # in lang.txt there is an explanation 
    settings="${settings}<p style=\"margin-left:30px;\">${settingTELBOOK_XML1}<br/></p>"
  fi  
fi
if [[ "$tbBookName" != "" ]]; then
  settings="${settings}${tbBookName#*<br>}<br/>"
  if [[ -n "${settingTELBOOKNAME}" ]]; then # in lang.txt there is an explanation 
    settings="${settings}<p style=\"margin-left:30px;\">${settingTELBOOKNAME}<br/></p>"
  fi  
fi
if [[ "$cw" != "" ]]; then
  settings="${settings}${cw#*<br>}<br/>" # remove 1st <br> and append to $settings
  if [[ -n "${settingCOLW}" ]]; then # in lang.txt there is an explanation 
    settings="${settings}<p style=\"margin-left:30px;\">${settingCOLW}<br/></p>"
  fi  
fi
settings="${settings}<p><strong>${runInstallationAgain}</strong></p><br/>"
# echo "settings='$settings'" >> "$LOG"

# Set environment variables
# --------------------------------------------------------------
# Set up folder for temporary data:
app_temp="${app_home}/temp" # /volume*/@appstore/${app_name}/ui/temp
#  or /volume*/@apptemp/$app_name ??
if [ ! -d "${app_temp}" ]; then
  mkdir -p -m 755 "${app_temp}"
fi
# result="${app_temp}/result.txt"

# Evaluate POST and GET requests and cache them in files
  # get_keyvalue="/bin/get_key_value"
# get_request="$app_temp/get_request.txt"

# If no page set, then show home page
#if [ -z "${get[page]}" ]; then
#  logInfoNoEcho 6 "generating file $get_request ..." # /volume1/@appstore/callmonitor/ui/temp/get_request.txt
#  /usr/syno/bin/synosetkeyvalue "${get_request}" "get[page]" "main"  # write and read an .ini style file with lines of key=value pairs
#  /usr/syno/bin/synosetkeyvalue "${get_request}" "get[section]" "start"
#  /usr/syno/bin/synosetkeyvalue "${get_request}" "get[SynoToken]" "$syno_token"
#fi

# Processing GET/POST request variables
# CONTENT_LENGTH: CGI meta variable https://stackoverflow.com/questions/59839481/what-is-the-content-length-varaible-of-a-cgi

# https://www.parckwart.de/computer_stuff/bash_and_cgi_parsing_get_and_post_requests
  #if [ -z "${POST_STRING}" ] && [ "${REQUEST_METHOD}" = "POST" ] && [ -n "${CONTENT_LENGTH}" ]; then
  #  read -n ${CONTENT_LENGTH} POST_STRING
  #fi


# Analyze incoming POST requests and process them to ${get[key]}="$value" variables
cgiDataEval # parse_hlp.sh, setup associative array get[] from the request (POST and GET)

if [[ -n "${get[action]}" ]]; then
  val="${get[action]}"
  # action=LedChange&led=7
  if [[ "$val" == "LedChange" ]]; then 
    val2="${get[led]}" # "%40"="@", "B", "8", or "7" # @ = 0x40  Copy LED on
    # res=$(/bin/echo "@" > /dev/ttyS1)  # not working!!! Would require root permission!
    # setup a job file and do it in the start-stop-status script at the periodically done status check:
    /bin/printf "%s\n" "$val2" >> "$appCfgDataPath/ledChange"
    ret=$?
    logInfoNoEcho 8 "'$val2' written to file '$appCfgDataPath/ledChange'"
  fi
fi

lngLoadErr=""
# Workaround if language loading failed:
if [[ "$btnShowSimpleLog" == "" ]]; then
  btnShowSimpleLog="Action Log"
  lngLoadErr="$lngLoadErr btnShowSimpleLog"
fi
if [[ "$btnAllCalls" == "" ]]; then
  btnAllCalls="All Calls"
  lngLoadErr="$lngLoadErr btnShowSimpleLog btnAllCalls"
fi
if [[ "$lngLoadOK" != "" ]]; then
  logInfoNoEcho 1 "Language specific Button Texts for language '${used_lang}' have not been loaded correctly: $lngLoadErr"
fi


# Layout output
# --------------------------------------------------------------
if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ]; then
  echo "Content-type: text/html; charset=utf-8"
  echo
  echo "
  <!doctype html>
  <html lang=\"${SYNO2ISO[${used_lang}]}\">
    <head>"
  echo '<meta charset="utf-8" />'
  echo "<title>${display_name}</title>"   # <title>...</title> is not displayed but title from the file config
  echo '
      <link rel="shortcut icon" href="images/icon_32.png" type="image/x-icon" />
      <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />
      <link rel="stylesheet" type="text/css" href="dsm3.css"/>
    </head>
    <body>
      <header></header>
      <article>'
        # Load page content
        # --------------------------------------------------------------
        if [[ "${is_admin}" == "yes" ]]; then
          # Infotext: Enable application level authentication
          # [ -n "${txtActivatePrivileg}" ] && echo ''${txtActivatePrivileg}''
          # Dynamic page output:
          #if [ -f "${get[page]}.sh" ]; then
          #  . ./"${get[page]}.sh"
          #else
          #  echo 'Page '${get[page]}'.sh not found!'
          #fi

          # HTTP GET and POST requests
          echo "<p><form><button onclick=\"location.href='log.cgi'\" type=\"button\">${btnShowSimpleLog}</button>"
          echo "<button onclick=\"location.href='calls.cgi?action=ALL'\" type=\"button\">${btnAllCalls}</button>"
          echo "<input type=\"button\" value=\"Zurück Back\" onclick=\"history.back()\"></form></p>"
          #echo '<br \>'
          echo "<p><strong>$st</strong></p>" # "Actual settings:"
          echo "${settings}"
        else
          # Infotext: Access allowed only for users from the Administrators group
          echo '<p>'${txtAlertOnlyAdmin}'</p>'
        fi
        if [[ "$fallbackToEnu" -eq "0" ]]; then
          echo '<p>'${txtLanguageSource}'</p>'
        else
          echo "<p>Could not find a supported language in your webbrowser regional preferences '${HTTP_ACCEPT_LANGUAGE}'. Therefore English is used.</p>"
        fi
        echo '
      </article>
    </body>
  </html>'
fi # if [ $(synogetkeyvalue /etc.defaults/VERSION majorversion) -ge 7 ]
logInfoNoEcho 6 "... $(basename "${BASH_SOURCE[0]}") done"
exit

