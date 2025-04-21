#!/bin/bash
# write an info entry to out log file
# included to scripts in folders WIZARD_UIFILES and scripts directly. 
# During the 1st start of start-stop-status script a link under /var/packages/$SYNOPKG_PKGNAME/target/ is generated for use in via the common.sh file.
# Hint: In the *.cgi files this is not used, only logInfoNoEcho() (located in parse_hlp.sh) is used.

# systemd-cat not available (https://serverfault.com/questions/573946/how-can-i-send-a-message-to-the-systemd-journal-from-the-command-line)
# https://serverfault.com/questions/573946/how-can-i-send-a-message-to-the-systemd-journal-from-the-command-line
# Redirect stderr such that any message is reported as an error to journald by
# prepending '<3>' to it. Use fd 4 (the saved stderr) to directly report other
# severity levels.
# exec 4>&2 2> >(while read -r REPLY; do printf >&4 '<3>%s\n' "$REPLY"; done)

# Systemd can kill the logging subshell swiftly when we exit, and lose messages.
# Close the subshell before exiting the main program explicitly. This will block
# until the read builtin reads the EOF.
# trap 'exec >&2-' EXIT

# echo >&2 "This message is logged as an error, red and bold."
# echo >&4 "<5>This is logged as a notice-level message, dim and boring."

# Variante a:  $1 = log entry
# Variante b: $1= LogLevel, $2 log entry: Only if $1 is smaler or equal to the loglevel it will be reported
logInfo() { # LogLevel 1=Error, 2=Warnings, 3=Info, 4...8 = Debug
  local ll=8 # log level defaultvalue
  if [[ "$1" =~ ^[0-9]+$ ]] && [[ $# -ge 2 ]]; then # Attention: No single or double quotes for regExp allowed!
    ll=$1 # 1st parameter is log level
    # /bin/echo "logInfo called with level $ll"
    shift
  fi
  # /bin/echo "logInfo with ll='$ll' and LOGLEVEL='$LOGLEVEL'"
  # /bin/echo "generating callerHistory now"
  local callerHistory
  callerHistory="$(basename "${BASH_SOURCE[1]}"):${BASH_LINENO[0]}"
  if [[ "$LOGLEVEL" -ge "5" ]]; then # full caller history only for high loglevel
    local i
    for (( i=2 ; i < "${#BASH_SOURCE[@]}"; i++ )); do
      callerHistory="$(basename "${BASH_SOURCE[$i]}"):${BASH_LINENO[$((i-1))]} -> $callerHistory"
      # https://stackoverflow.com/questions/192319/how-do-i-know-the-script-file-name-in-a-bash-script
    done
  fi
  spanStart=""
  spanEnd=""
  if [[ "$ll" -eq "1" ]]; then # Error
    spanStart="<span style=\"color:red;\">"
    spanEnd="</span>"  
  fi

  if [[ "$ll" -le  "$LOGLEVEL" ]]; then
    if [[ "$ll" -le  "1" ]]; then # Error
      # https://devops.com/syslogs-in-linux-understanding-facilities-and-levels/
      logger -p local3.err "$SYNOPKG_PKGNAME $callerHistory $*"
    else
      # logger "$SYNOPKG_PKGNAME $callerHistory $*"
      logger -p local3.info "$SYNOPKG_PKGNAME $callerHistory $*"
    fi

    i=0 # logfile owner my be e.g. root while running as user $SYNOPKG_PKGNAME
    while (( i < 3 )) && [[ ! -w "$LOG" ]];do
      LOG="${LOG}$i"
      ((i=i+1))
    done

    if [[ $- == *i* ]] || [[ -n "$PS1" ]]; then # interactive shell, [[ -n "$PS1" ]] would also be possible
      /bin/printf "%s\t%s\n" "$(date "$DTFMT") ${callerHistory}" "${spanStart}${*//\\n/<br>}${spanEnd}" | /bin/tee -a "$LOG"
	  # ${*//$'\n'/<br>} ???
    else
      /bin/printf "%s\t%s\n" "$(date "$DTFMT") ${callerHistory}" "${spanStart}${*//\\n/<br>}${spanEnd}" >> "$LOG"
	  # ${*//$'\n'/<br>} ???
    fi
  fi
  if [[ "$LOGCENTER" -gt "0" ]]; then # Logging to Synology Log Center is not disabled
    # 1 Errors only, 2 Errors and warnings, 3 Errors, warnings and infos, 4 Errors, warnings, infos and debug
    if [[ "$SYSLOG_INT" == "true" ]] && [[ "$ll" -le "3" ]]; then # via synologset1 as Local General System
      if [[ "$ll" -le "1" ]];then
        /usr/syno/bin/synologset1 sys err 0x11100600 "$SYNOPKG_PKGNAME $callerHistory" "$*"
        logger "$SYNOPKG_PKGNAME $callerHistory $*"
      elif [[ "$ll" -le "2" ]];then
        /usr/syno/bin/synologset1 sys warn 0x11100600 "$SYNOPKG_PKGNAME $callerHistory" "$*"

      elif [[ "$ll" -le "3" ]]; then
        /usr/syno/bin/synologset1 sys info 0x11100600 "$SYNOPKG_PKGNAME $callerHistory" "$*"
      fi
    fi  
    if [[ "$SYSLOG_UDP" == "true" ]];then # during upgradeuifile.sh $SYSLOG_UDP may be undefined
      # Logging via UDP as localhost All user or local0 ... local7
      if [[ -z $SYSLOG_PORT ]]; then
        /usr/syno/bin/synologset1 sys err  0x11100600 "$SYNOPKG_PKGNAME $callerHistory" "SYSLOG_PORT undefined, using 514!"
        SYSLOG_PORT=514
      fi
      # severity err = 3, facility user=1*8, local0=16*8=128
      facility=$LOGFACILITY;
      if [[ "$facility" -ne "8" ]]; then # 8 = 1*8 = user
        fac="local$facility"
        # facility=$((8*(16+facility))) # local0 ... local7
      else
        fac="user"  
      fi
      if [[ "$ll" -le "1" ]];then # err
        # severity=3
        fac="${fac}.error"
      elif [[ "$ll" -le "2" ]];then # warn
        # severity=4
        fac="${fac}.warning"
      elif [[ "$ll" -le "3" ]]; then # info
        # severity=6
        fac="${fac}.info"
      else 
        # severity=7 # Debug        
        fac="${fac}.debug"
      fi
      lll=$ll
      if [[ "$lll" -gt "4" ]]; then # set all debug levels 4...8 to 4
        lll=4
      fi
      if [[ "$lll" -le "$LOGCENTER" ]]; then # e.g. send only ERR (if $LOGCENTER == 1)
        # pri=$((severity + facility));
        # /bin/echo "<${pri}>${callerHistory}: $*" > /dev/udp/localhost/"$SYSLOG_PORT"
        # /bin/logger -n localhost --prio-prefix -P "$SYSLOG_PORT" "<$pri>${callerHistory}: $*"
        # --prio-prefix        look for a prefix on every line read from stdin is not working!!!!
        /bin/logger -n localhost -p "$fac"  -P "$SYSLOG_PORT" "$SYNOPKG_PKGNAME ${callerHistory}: $*"
        /bin/printf "%s\t%s\n" "$(date "$DTFMT") ${callerHistory}" "logger cmd done with ll='$ll', lll='$lll' -le LOGCENTER='$LOGCENTER'" >> "$LOG"
      fi
    fi
  fi
}


# write an error entry to out log file
logError() {  # logError "Message" is equal to logInfo 1 "Message"
  logInfo 1 "$@"
}


##### global ####
DTFMT="+%Y-%m-%d %H:%M:%S"
msglh=""
if [[ -n "${app_name}" ]] && [[ -z "${SYNOPKG_PKGNAME}" ]];then
  SYNOPKG_PKGNAME="${app_name}"
  msglh="$msglh, SYNOPKG_PKGNAME set from app_name to '${app_name}'"
fi
if [[ -z "${SYNOPKG_PKGNAME}" ]];then
  SYNOPKG_PKGNAME="UNKNOWN_PACKAGE"
  msglh="$msglh, app_name and SYNOPKG_PKGNAME both have been empty!"
fi
# shellcheck disable=SC2164
SCRIPTPATHloghlp="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
# install_uifile.sh:18 -> log_hlp.sh:193	Skriptpath: /volume1/@tmp/synopkg/wizard.3bG3zk/WIZARD_UIFILES
# preinst:16           -> log_hlp.sh:193	Skriptpath: /volume1/@tmp/synopkg/install.IJddkk/WIZARD_UIFILES
# postinst:8           -> log_hlp.sh:193	Skriptpath: /var/packages/<paket>/WIZARD_UIFILES
msglh="$msglh, Skriptpath: $SCRIPTPATHloghlp"
SCRIPTPATHloghlp=$(readlink -m "$SCRIPTPATHloghlp")
msglh="${msglh}=$SCRIPTPATHloghlp"
# scriptpathLoghlpParent=${SCRIPTPATHloghlp%/*}

unset msglh2
if [[ -z "$LOG" ]];then
  # shellcheck disable=SC2164
  #SCRIPTPATHlh="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
  #lgf="${SCRIPTPATHlh%%/@*}/@appdata/${SYNOPKG_PKGNAME}/inst.log"
  #/bin/touch "$lgf"
  #if [[ -w "$lgf" ]]; then
  #  LOG=$lgf
  #fi
  if [[ ! -f "/var/log/packages/$SYNOPKG_PKGNAME.log" ]]; then 
    /bin/touch "/var/log/packages/$SYNOPKG_PKGNAME.log" # generate file, may be not possible
  fi
  if [[ -f "/var/log/packages/$SYNOPKG_PKGNAME.log" ]]; then 
    logUser=$(stat -c '%U' "/var/log/packages/${SYNOPKG_PKGNAME}.log")
  fi
  if [[ "$(whoami)" == "root" ]] && [[ "$logUser" != "$SYNOPKG_PKGNAME" ]] && [[ "$SYNOPKG_PKGNAME" != "UNKNOWN_PACKAGE" ]]; then
    chmod 666 "/var/log/packages/$SYNOPKG_PKGNAME.log"
    chown "$SYNOPKG_PKGNAME":"$SYNOPKG_PKGNAME" "/var/log/packages/$SYNOPKG_PKGNAME.log" 
    msglh2="owner of /var/log/packages/$SYNOPKG_PKGNAME.log tried to changed from $logUser to $SYNOPKG_PKGNAME"
    logUser=$(stat -c '%U' "/var/log/packages/${SYNOPKG_PKGNAME}.log")
    if [[ $logUser != "$SYNOPKG_PKGNAME" ]]; then
      msglh2="$msglh2, but that failed, user is still $logUser"
    fi
  fi
  if [[ -w "/var/log/packages/$SYNOPKG_PKGNAME.log" ]]; then # exists and writeable
    LOG="/var/log/packages/$SYNOPKG_PKGNAME.log"
    if [[ $(basename "${BASH_SOURCE[1]}") == "upgrade_uifile.sh" ]]; then
      logInfo 5 "From a previous installation of the package '$SYNOPKG_PKGNAME' the logfile '$LOG' is already writable for the user '$(whoami)'"
    # else: at 1st installation not writable during execution of install_uifile.sh and upgrade_uifile.sh!
    fi  
  else
    if [[ ! -d "/var/tmp" ]]; then
      mkdir "/var/tmp" # if nginx is used, this will already exist
    fi
    if [[ -f "/var/tmp/$SYNOPKG_PKGNAME.log" ]]; then
      touch "/var/tmp/$SYNOPKG_PKGNAME.log"
    fi
    if [[ -w "/var/tmp/$SYNOPKG_PKGNAME.log" ]]; then
      LOG="/var/tmp/$SYNOPKG_PKGNAME.log"
      msglh="$msglh, can't use /var/log/packages/$SYNOPKG_PKGNAME.log, using /var/tmp/$SYNOPKG_PKGNAME.log"
    else
      LOG="/tmp/$SYNOPKG_PKGNAME.log"
      msglh="$msglh, can't use /var/log/packages/$SYNOPKG_PKGNAME.log or /var/tmp/$SYNOPKG_PKGNAME.log, using $LOG. user is $(whoami)"
    fi
  fi
  # echo >&4 "Using $LOG for logs"
  msglh="$msglh, LOG was now set to '$LOG'"
fi # if [[ -z "$LOG" ]]

# shellcheck disable=SC2164
SCRIPTPATHwiz="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
# configFilePathName="${SCRIPTPATHwiz%%/@*}/@appdata/${SYNOPKG_PKGNAME}/config" # ${SCRIPTPATHwiz%%/@*} gives e.g. /volume1
if [[ ${SCRIPTPATHwiz} =~ /var/* ]]; then # /var/packages/<paket>/WIZARD_UIFILES, postinst
  configFilePathName="${SCRIPTPATHwiz%/*}/var/config"
  msglh="$msglh, \n '/var/' found in Scriptpath, config-file expected as 'configFilePathName'"
  # failing at initial installation!???
elif [[ ${SCRIPTPATHwiz} =~ /volume* ]]; then # /volume1/@tmp/synopkg/install.IJddkk/WIZARD_UIFILES, install_uifile.sh, preinst
  configFilePathName="${SCRIPTPATHwiz%%/@*}/@appdata/${SYNOPKG_PKGNAME}/config" # ${SCRIPTPATHwiz%%/@*} gives e.g. /volume1
  msglh="$msglh, \n '/volume' found in Scriptpath, config-file expected as 'configFilePathName'"
else
  msglh="$msglh, SCRIPTPATHwiz not /var/* and not /volume*"
fi
if [[ -z "$LOGLEVEL" ]]; then
  msglh="$msglh\nTrying to get LOGLEVEL from $configFilePathName"
  # Trying to get LOGLEVEL from /volume1/@appdata/<paket>/config
  # Trying to get LOGLEVEL from /var/packages/<paket>/var/config
  if [[ -f "$configFilePathName" ]]; then
    LOGLEVEL=$(grep -i "LOGLEVEL=" "$configFilePathName" | /bin/sed -e 's/^LOGLEVEL="//i' -e 's/"$//')
    if ! [[ $LOGLEVEL =~ ^[0-9]+$ ]] ; then
      msgX="Error: LOGLEVEL=${LOGLEVEL} is not numerical!"
      LOGLEVEL=8
      logError "$msgX"
    fi
  else
    msglh="$msglh but file not available"
    configFilePathName=$(readlink -m "$configFilePathName")
    if [[ -f "$configFilePathName" ]]; then
      msglh="$msglh, found as $configFilePathName"
      LOGLEVEL=$(grep -i "LOGLEVEL=" "$configFilePathName" | /bin/sed -e 's/^LOGLEVEL="//i' -e 's/"$//')
    fi
  fi
  if [[ -z "$LOGLEVEL" ]];then
    LOGLEVEL=8;
    msglh="$msglh, no LOGLEVEL found in config or no config file found, LOGLEVEL set to 8"
  fi
fi

if [[ -n "$msglh2" ]]; then
  logInfo 5 "$msglh2, previous logs may be found in /var/tmp/$SYNOPKG_PKGNAME.log or /tmp/$SYNOPKG_PKGNAME.log"
fi
if [[ -n "$msglh" ]] && [ -z "$log_hlp_msg_done" ]; then
  if [[ $(basename "${BASH_SOURCE[1]}") != "start-stop-status" ]]; then
    # skip message if called from start-stop-status, as this occures periodically
    logInfo 4 "${msglh/#, /}"
  fi
  export log_hlp_msg_done=1
fi
# /bin/echo "LOGLEVEL set to $LOGLEVEL"
