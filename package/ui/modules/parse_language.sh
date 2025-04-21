#!/bin/bash
# Filename: parse_language.sh - coded in utf-8
# taken from
#   SPKdevDSM7
#   Copyright (C) 2022 by Tommes
#   Member of the German Synology Community Forum
#     License GNU GPLv3
#   https://www.gnu.org/licenses/gpl-3.0.html

# Adopted to the needs of Autorun and CallMonitor by Horst Schmid
#      Copyright (C) 2022...2024 by Horst Schmid

#********************************************************************#
#  Description: Script get the currently used language               #
#               Either the language setup for the logged-in user     #
#               or the language according the web browser setup      #
#               or the setup for the DSM display or DSM messages     #
#  Author 1:    QTip from the german Synology support forum          #
#  Copyright:   2016-2018 by QTip                                    #
#  Author 2:    Modified 2022 by Tommes                              #
#  Author 3:    Horst Schmid, 2022...2023                            #
#  License:     GNU GPLv3                                            #
#  ----------------------------------------------------------------  #
#  Version:     2023-01-06                                           #
#********************************************************************#
bDebugPL=0
DTFMT="+%Y-%m-%d %H:%M:%S"
SCRIPTPATHTHISpl="$( cd -- "$(/bin/dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
scriptpathParentPl=${SCRIPTPATHTHISpl%/*}
if [[ -z "$SCRIPT_NAME" ]]; then  # direct start in debug run
 # e.g. /volumeX/@appstore/<app>/ui
  cd "$scriptpathParentPl"
  app_name="callmonitor"  # may be needed to change if appName is changed!
  SCRIPT_NAME="/webman/3rdparty/${app_name}"
  echo "parse_language.sh started and switched to debug mode ..."
  bDebugPL=1
  source "$SCRIPTPATHTHISpl/parse_hlp.sh"
else
  app_link=${SCRIPT_NAME%/*} # "/webman/3rdparty/<appName>"
  app_name=${app_link##*/} # "<appName>"
fi
if [[ -z "$LOG" ]]; then
  if [[ -w "/var/log/packages/${app_name}.log" ]]; then
    LOG="/var/log/packages/${app_name}.log"
  elif [[ -w "/var/tmp/${app_name}.log" ]]; then
    LOG="/var/tmp/${app_name}.log"  # no permission if default -rw-r--r-- root:root was not changed
  fi
fi
logInfoNoEcho 6 "parse_language.sh started with param1='$1', whoami=$(whoami) ..."
if [[ "$bDebugPL" -eq "1" ]]; then
  echo "see $LOG"
fi
# # even if we have had ${login_result} != "success" in showlog.cgi, then still no access!
# usersettingsfile="/usr/syno/etc/preference/${user}/usersettings"
# Therefore languages are pre-fetched in the start-stop script:
# DSM language
gui_lang=$(/bin/get_key_value /etc/synoinfo.conf language) # Display language, may be 'def'!
declare -A ISO2SYNO
ISO2SYNO=( ["de"]="ger" ["en"]="enu" ["zh"]="chs" ["cs"]="csy" ["jp"]="jpn" ["ko"]="krn" ["da"]="dan" ["fr"]="fre" ["it"]="ita" ["nl"]="nld" ["no"]="nor" ["pl"]="plk" ["ru"]="rus" ["sp"]="spn" ["sv"]="sve" ["hu"]="hun" ["tr"]="trk" ["pt-BR"]="ptb" ["pt"]="ptg" ["pt-PT"]="ptg" )
declare -A SYNO2ISO # used in *.cgi files
# shellcheck disable=2034
SYNO2ISO=(   ["ger"]="de" ["enu"]="en" ["chs"]="zh" ["csy"]="cs" ["jpn"]="jp" ["krn"]="ko" ["dan"]="da" ["fre"]="fr" ["ita"]="it" ["nld"]="nl" ["nor"]="no" ["plk"]="pl" ["rus"]="ru" ["spn"]="sp" ["sve"]="sv" ["hun"]="hu" ["trk"]="tr" ["ptg"]="pt"  ["ptb"]="pt-BR" )
# SYNO2ISO=( ["ger"]="de" ["enu"]="en" ["chs"]="zh" ["csy"]="cs" ["jpn"]="ja" ["krn"]="ko" ["dan"]="da" ["fre"]="fr" ["ita"]="it" ["nld"]="nl"              ["plk"]="pl" ["rus"]="ru" ["spn"]="es" ["sve"]="sv" ["hun"]="hu" ["trk"]="tr" ["ptb"]="pt-BR" ["ptg"]="pt-PT" )
# Japan: ja (FIPS 10 = U.S. Federal Information Processing Standard No. 10) or jp (ISO 3166-1)?

if [[ -n "$SYNOPKG_DSM_LANGUAGE" ]]; then # Language of the logged-in user, in cgi files not available
  lngDsmUser="$SYNOPKG_DSM_LANGUAGE"
fi

if [[ -n "${LANG}" ]]; then # in cgi files not set
  logInfoNoEcho 8 "env LANG='$LANG'"
  env_lng="${LANG:0:2}"
  env_lng=${ISO2SYNO[$env_lng]}
fi

lngDsm2=$(/bin/get_key_value "/etc/synoinfo.conf" "language") # Display Language, may be "def"
lngMail=$(/bin/get_key_value "/etc/synoinfo.conf" "maillang") # Notification Language, e.g. ger, global setting, not individual user!

httpSynLngs=""
if [ -n "${HTTP_ACCEPT_LANGUAGE}" ] ; then  # WebBrowser-Preset available in cgi files, e.g. 'de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7'
  # try to translate the ISO language codes now to SYNO language codes:
  # logInfoNoEcho 6 "From web browser regional settings: HTTP_ACCEPT_LANGUAGE='${HTTP_ACCEPT_LANGUAGE}'"
  if [[ -n "${HTTP_ACCEPT_LANGUAGE}" ]]; then
    # mapfile -d "," -t httpLngs <<< "${HTTP_ACCEPT_LANGUAGE}" # here-string <<< appends a newline!
    mapfile -d "," -t httpLngs < <(/bin/printf '%s' "$HTTP_ACCEPT_LANGUAGE") # process substitution should be available also in ash with bash-compatibility
    # httpLngs[-1]=$(echo "${httpLngs[-1]}" | sed -z 's|\n$||' ) # remove the \n which was appended to last item by "<<<"
    msg1="${#httpLngs[@]} Elments in httpLngs[@]:"
    for ((i=0; i<${#httpLngs[@]}; i+=1)); do
      b1=${httpLngs[i]%%;*} # remove e.g. ";q=0.7", remaining e.g. "pt-PT, de-DE"
      b2=${httpLngs[i]:0:2}
      b2=${b2,,} # to lower case, should not be necessary
      msg1="$msg1 ${httpLngs[i]}"
      [[ -n ${ISO2SYNO[$b1]} ]] && msg1="$msg1, b1='$b1'==>'${ISO2SYNO[$b1]}"
      [[ -n ${ISO2SYNO[$b1]} ]] && msg1="$msg1, b2='$b2'==>'${ISO2SYNO[$b2]}"
      if [[ -n "${ISO2SYNO[$b1]}" ]] && [[ "$httpSynLngs" != *"${ISO2SYNO[$b1]}"* ]]; then
        httpSynLngs="$httpSynLngs${ISO2SYNO[$b1]} "
      elif [[ -n "${ISO2SYNO[$b2]}" ]] && [[ "$httpSynLngs" != *"${ISO2SYNO[$b2]}"* ]]; then
        httpSynLngs="$httpSynLngs${ISO2SYNO[$b2]} "
      elif [[ -z "${ISO2SYNO[$b1]}" ]] && [[ -z "${ISO2SYNO[$b2]}" ]]; then
        msg1="$msg1: no Syno language"
      fi
    done
    # logInfoNoEcho 6 "From web browser regional settings: HTTP_ACCEPT_LANGUAGE='${HTTP_ACCEPT_LANGUAGE}'<br>$msg1"
  fi
fi

# logInfoNoEcho 8 "From web browser regional settings: HTTP_ACCEPT_LANGUAGE='${HTTP_ACCEPT_LANGUAGE}'<br>${msg1}<br>lngDsmUser='$lngDsmUser', httpLng='$httpSynLngs',lngDsm2='$lngDsm2', env_LANG='$env_lng', gui_lang='$gui_lang', lngMail='$lngMail'"
# shellcheck disable=2206
languages=( $lngDsmUser $httpSynLngs $lngDsm2 $env_lng $gui_lang $lngMail )
# logInfoNoEcho 6 "languages with precedence to check for an available translation: ${languages[@]}"
used_lang=""
for lngx in "${languages[@]}"; do
  if [[ -n "$lngx" ]] && [[ "$lngx" != "def" ]]; then
    if [[ -f "$scriptpathParentPl/texts/${lngx}/lang.txt" ]]; then
      used_lang=$lngx
      break
    else
      logInfoNoEcho 6 "No translation file '$scriptpathParentPl/texts/${lngx}/lang.txt' found for '$lngx'"
    fi
  fi
done
if [[ -z "$used_lang" ]]; then
  used_lang="enu"
  logInfoNoEcho 3 "Language fallback to English as no other selection found"
fi
# shellcheck disable=2034
lngUser=$used_lang
# logInfoNoEcho 6 "Selected Language '$used_lang'"
lngFile="$scriptpathParentPl/texts/${used_lang}/lang.txt"
if [[ ! -f "$lngFile" ]]; then
  # logError "File '$lngFile' not available. pwd='$(/bin/pwd)'" # logError not available in settings.cgi
  logInfoNoEcho 4 "File '$lngFile' not available. pwd='$(/bin/pwd)'"
fi
# shellcheck source=../texts/enu/lang.txt
# res="$(source "$lngFile" 2>&1)" # setup $fingerprint0, $fingerprint1count0, $fingerprint1count1, $fingerprint2, ...
# Values set in SubShell would be lost!
# https://stackoverflow.com/questions/66831836/how-to-capture-redirect-stdout-stderr-from-a-source-command-into-a-variable-i
source "$lngFile" # setup $fingerprint0, $fingerprint1count0, $fingerprint1count1, $fingerprint2, ...
ret=$?
# logInfoNoEcho 7 "Result from 'source $lngFile' is '$res'"
if [[ "$ret" -ne 0 ]]; then
  # shellcheck source=../texts/ger/lang.txt
  res="$(source "$lngFile" 2>&1)" # do again with catching result
  logInfoNoEcho 1 "<span style='color:red'>Bad result $ret from 'source $lngFile' is '${res//$'\n'/<br />}'</span>!"
  if [[ "$used_lang" != "enu" ]]; then
  # try fallback to English:
    # shellcheck source=../texts/enu/lang.txt
    # res="$(source "texts/enu/lang.txt" 2>&1)" # Values set in SubShell would be lost
    source "texts/enu/lang.txt"
    ret=$?
    logInfoNoEcho 7 "Result $ret from 'source texts/enu/lang.txt' is '${res//$'\n'/<br />}'"
    if [[ "$ret" -ne 0 ]]; then
      res="$(source "$scriptpathParentPl/texts/enu/lang.txt" 2>&1)" # do again with catching result
      logInfoNoEcho 1 "<span style='color:red'>Failed to fallback to Englisch, result from 'source texts/enu/lang.txt' is '${res//$'\n'/<br />}'</span>"
      # dsmnotify
    fi # if [[ "$res" -ne 0 ]]
  fi # if [[ "$used_lang" != "enu" ]]
else
  logInfoNoEcho 8 "source $lngFile successfully done with result 0: '${res//$'\n'/<br />}'"
fi # if [[ "$res" -ne 0 ]]
if [[ $bDebugPL -eq 1 ]]; then
  echo "... parse_language.sh done with res=$res"
fi
logInfoNoEcho 6 "... parse_language.sh done, language set to '$used_lang'"
