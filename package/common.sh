#!/bin/bash
# used by start-stop-status for lngUser

####################### start #############################
if [[ -z "$PATH" ]]; then
  PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin
fi
# shellcheck disable=SC2164
SCRIPTPATHTHIScommon="$( cd -- "$(/bin/dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )" # e.g. /volumeX/@appstore/<app>
# Attention: In case of "source <somePath>/common" don't overwrite here the previous SCRIPTPATHTHIS!
if [[ -z "${app_name}" ]]; then
  app_name="${SCRIPTPATHTHIScommon##*/}"
fi
APPDATA="/var/packages/$app_name/var" # appCfgDataPath="/var/packages/${app_name}/var"
# shellcheck disable=SC2034
LOGLEVEL=8 # preset, may be chanded in parse_hlp.sh from config 
# shellcheck source=../WIZARD_UIFILES/log_hlp.sh
# shellcheck disable=SC1091
source "/var/packages/$app_name/WIZARD_UIFILES/log_hlp.sh"
# shellcheck source=ui\modules\parse_hlp.sh
# shellcheck disable=SC1091
source "/var/packages/$app_name/target/ui/modules/parse_hlp.sh" #  logInfoNoEcho(), DTFMT, LOGLEVEL, urlencode(), urldecode()
# shellcheck disable=SC2034
SCRIPT_EXEC_LOG="$APPDATA/execLog"

# shellcheck source=..\WIZARD_UIFILES\initial_config.txt
# shellcheck disable=SC1091
source "$APPDATA/config"
if [[ -z "$LOG" ]]; then # should be set in log_hlp.sh!!!!!
  if [[ -w "/var/log/packages/$app_name.log" ]]; then
    LOG="/var/log/packages/$app_name.log"
  fi
  ## LOG="/var/packages/$app_name/target/log"
  # LOG="$APPDATA/log" # equal to /volumeX/@appdata/<app>
  # LOG="/var/log/packages/$app_name.log" # permission denied
  # /var/log/$app_name.log: Permission denied
  if [[ -z "$LOG" ]]; then
    LOG="/var/tmp/$app_name.log"
  fi
  logInfo 2 "LOGFILE was not set! Now='$LOG'"
fi
# A link /var/packages/$SYNOPKG_PKGNAME/var/detailLog to $LOG is set to this (see start-stop-status script)
logInfo 7 "common.sh (${BASH_SOURCE[0]}) was called with param1='$1', app_name='$app_name', APPDATA='$APPDATA', SCRIPTPATHTHIScommon='$SCRIPTPATHTHIScommon'"
lngUser=$SYNOPKG_DSM_LANGUAGE # not global DSM language but actual user language! Never 'def'
lngMail=$(/bin/get_key_value "/etc/synoinfo.conf" "maillang") # global setting, not individual user!
if [[ -z "$lngUser" ]]; then
  # logInfo 5 "common.sh: SYNOPKG_DSM_LANGUAGE is not available, trying maillang='$lngMail'"
  lngUser="$lngMail"  
fi
if [[ ! -f "/var/packages/$app_name/target/ui/texts/$lngUser/lang.txt" ]]; then
  logInfo 5 "common.sh: /var/packages/$app_name/target/ui/texts/$lngUser/lang.txt not available, switched to enu"
  lngUser="enu"
fi
if [[ "$1" != 'udev' ]]; then # when called from udev the language is not important and the user is root
  user=$(whoami) # EnvVar $USER may be not well set
  logInfo 7 "common.sh done: user='$user', SYNOPKG_DSM_LANGUAGE='$SYNOPKG_DSM_LANGUAGE', lngMail='$lngMail', selected lngUser='$lngUser'"
fi
