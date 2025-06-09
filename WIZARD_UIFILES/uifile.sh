#!/bin/bash
# shellcheck disable=SC2034
DTFMT="+%Y-%m-%d %H:%M:%S"

############################ start #########################
# Hint: the installation wizard copies this to e.g. /volume1/@tmp/synopkg/wizard.PIl9Wu/WIZARD_UIFILES
# The file properties will be 0755/drwxr-xr-x root:root, but it will be executed as user '$SYNOPKG_PKGNAME'
# Seems to be started with somthing like "sudo -u $SYNOPKG_PKGNAME install_uifile.sh"
msg=""

# LOG="/tmp/callmonitor.log"

if [[ -z "$SYNOPKG_PKGNAME" ]]; then # may be direkt start for debugging
  # $SYNOPKG_PKGNAME is available if pre-processing was well done!
  SYNOPKG_PKGNAME="callmonitor"
  msg="Error: Env SYNOPKG_PKGNAME was not set!"
  # shellcheck disable=SC2034
  LOGLEVEL=8
fi
# Can we read old LogLevel configuration?
# shellcheck disable=SC2164
SCRIPTPATHwiz="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
if [[ -f "${SCRIPTPATHwiz}/log_hlp.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPTPATHwiz}/log_hlp.sh"
else
  msg="$msg, Error: '${SCRIPTPATHwiz}/log_hlp.sh' not found!"
  echo "Error: '${SCRIPTPATHwiz}/log_hlp.sh' not found!" 1>&2
fi
logInfo 7 "Start of ${BASH_SOURCE[0]} with parameters: '$*'"
# after uninstall is /var/packages/$SYNOPKG_PKGNAME no more available, only /volume1/@appdata/<appName>/config !!!
configFilePathName="${SCRIPTPATHwiz%%/@*}/@appdata/${SYNOPKG_PKGNAME}/config"
# scriptpathParent=${SCRIPTPATHwiz%/*}
logInfo 5 "Running as user='$(whoami)', putting values from wizard_XXX.json and the config file to $SYNOPKG_TEMP_LOGFILE, which replaces upgrade_uifile"
# $SYNOPKG_TEMP_LOGFILE is e.g. /var/run/synopkgs/synopkgwizard.log.YzJhP5
if [[ -n "$msg" ]]; then
  # logInfo 4 "$msg"
  echo "$msg" >> "$LOG"
fi
logInfo 7 "id: $(id), $(basename "${BASH_SOURCE[0]}"): $(stat "${BASH_SOURCE[0]}" | grep "Access: ("), cmdline='$(tr '\0' ' ' </proc/$PPID/cmdline)'"
 # id: uid=<pkgName> gid=<pkgName> groups=<pkgName>,1(system),999(synopkgs),1023(http)
folder="$(dirname "${BASH_SOURCE[0]}")" # e.g. /volume1/@tmp/synopkg/wizard.HmIKuj/WIZARD_UIFILES/, Access: (0755/drwxr-xr-x) Uid: ( 0/ root) Gid: ( 0/ root)
# under e.g. /volume1/@tmp/synopkg/wizard.HmIKuj we have the files extracted from the outer tar. The inner tar "package.tgz" is not yet extracted!
folderTmp="${folder%%/synopkg*}" # Access: (1777/drwxrwxrwt) Uid: ( 0/ root) Gid: ( 0/ root)
logInfo 7 "$folder: $(stat "$folder" | grep "Access: ("), $folderTmp: $(stat "$folderTmp" | grep "Access: (")"
if [[ -n "$SYNOPKG_DSM_LANGUAGE" ]]; then
  lng="$SYNOPKG_DSM_LANGUAGE" # lng of actual user
  logInfo 6 "Language from environment SYNOPKG_DSM_LANGUAGE: '$lng'" # normally available, lng of actual user
else
  declare -A ISO2SYNO
  ISO2SYNO=( ["de"]="ger" ["en"]="enu" ["zh"]="chs" ["cs"]="csy" ["jp"]="jpn" ["ko"]="krn" ["da"]="dan" ["fr"]="fre" ["it"]="ita" ["nl"]="nld" ["no"]="nor" ["pl"]="plk" ["ru"]="rus" ["sp"]="spn" ["sv"]="sve" ["hu"]="hun" ["tr"]="trk" ["pt"]="ptg" )
  if [[ -n "${LANG}" ]]; then
    env_lng="${LANG:0:2}"
    lng=${ISO2SYNO[$env_lng]}
  fi
fi
if [[ -z "$lng" ]] || [[ "$lng" == "def" ]]; then
  lng="enu"
  logInfo 5 "No language in environment found, using 'enu'"
fi
logInfo 4 "Installing version $SYNOPKG_PKGVER over $SYNOPKG_OLD_PKGVER";
# Attention: In upgrade_uifile.sh $SYNOPKG_PKGVER is wrong, it's the old Version!

JSON="$(dirname "${BASH_SOURCE[0]}")/wizard_$lng.json"
if [[ ! -f "$JSON" ]]; then # no translation to the actual language available
  JSON=$(dirname "${BASH_SOURCE[0]}")/wizard_enu.json # using English version
fi
if [ ! -f "$JSON" ]; then
  logError "ERROR 11: WIZARD template file '$JSON' not available!"
  echo "[]" >> "$SYNOPKG_TEMP_LOGFILE"
  logError "No upgrade_uifile ($$SYNOPKG_TEMP_LOGFILE) generated (only empty file)"
  exit 11 # should we use exit 0 ?
fi
logInfo 6 "WIZARD template file '$JSON' is available"
if [ ! -f "$configFilePathName" ]; then
  logInfo 7 "No old configuration file '$configFilePathName' from a previous installation found, using initial config"
  configFilePathName="$(dirname "${BASH_SOURCE[0]}")/initial_config.txt"
  if [ ! -f "$configFilePathName" ]; then
    logError "Error: initial_config.txt not found!"
    echo "[]" >> "$SYNOPKG_TEMP_LOGFILE"
    logError "No upgrade_uifile ($SYNOPKG_TEMP_LOGFILE) generated (only empty file)" >> "$LOG"
    exit 12
  fi
fi
logInfo 7 "Used config file: '$configFilePathName'"

cat "$JSON" >> "$SYNOPKG_TEMP_LOGFILE" # language dependent file for the Installation wizzard

fields="" # get all the items names from the initial_config.txt file
file="$(dirname "${BASH_SOURCE[0]}")/initial_config.txt"
if [[ ! -f "$file" ]]; then
  logError "Error: initial_config.txt not found!"
  exit 14
fi
logInfo 7 "getting item names from '$(dirname "${BASH_SOURCE[0]}")/initial_config.txt'..."
while read -r line; do
  if [[ "$line" != "#"* ]]; then
    fields="$fields${line%%=*} "
  fi
done < "$(dirname "${BASH_SOURCE[0]}")/initial_config.txt"
logInfo 7 "...done, Items are '$fields'"

# build.sh should replace this:
VERSION_NOW="0.0.1-0003"
# This is a workaraound as $SYNOPKG_PKGVER is wrong here during upgrade installation!

msg=""
for f1 in $fields; do
  # get the item value now either from latest configuration (if it was not deleted at uninstall) or the default value from the intial config file
  # and replace the place holders @...@ in $SYNOPKG_TEMP_LOGFILE by the value
  line=$(grep "^$f1=" "$configFilePathName")
  if [[ -z "$line" ]]; then # new item in this version
    hint=" (default)"
    line=$(grep "^$f1=" "$(dirname "${BASH_SOURCE[0]}")/initial_config.txt")  # fetch it from file with defaults
  else
    hint=" (prev. cfg)"
  fi
  # eval "$line" # not secure, code injection may be possible
  declare "$f1"="$(sed -e 's/^"//' -e 's/"$//' <<<"${line#*=}")"
  msg="$msg, $f1='${!f1}'$hint"

  # Replace now in upgrade_uifile the placeholders like '@SCRIPT@' by the value 
  # As e.g. 
  #   "defaultValue": @SYSLOG_INT@
  # would be a XML syntax error and e.g.
  #   "defaultValue": "true"
  # is not working: Replace quoted placeholder for true and false:
  if [[ "${f1}" == "LICENSE_ACCEPTED" ]]; then
    msg="$msg (V $SYNOPKG_OLD_PKGVER => $VERSION_NOW (SYNOPKG_PKGVER=$SYNOPKG_PKGVER))"
  fi  
  if [[ "${!f1}" == "true" ]] || [[ "${!f1}" == "false" ]]; then # Quotes need to be removed
    if [[ "${f1}" == "LICENSE_ACCEPTED" ]] && [[ "$SYNOPKG_OLD_PKGVER" != "$VERSION_NOW" ]]; then
      # Attention: During upgrade_uifile.sh $SYNOPKG_PKGVER is wrong, it's the old Version!
      msg="$msg (V $SYNOPKG_OLD_PKGVER => $VERSION_NOW)"
      sed -i -e "s|\"@${f1}@\"|false|g" "$SYNOPKG_TEMP_LOGFILE" # for new version: manual licence aceptance
    else
      sed -i -e "s|\"@${f1}@\"|${!f1}|g" "$SYNOPKG_TEMP_LOGFILE" # other items or accepted licence for re-installation 
    fi
  else # for other placeholders preserve the quotes:
    sed -i -e "s|@${f1}@|${!f1}|g" "$SYNOPKG_TEMP_LOGFILE" 
  fi
done
logInfo 7 "Found settings: ${msg:1}"

if [[ -z "$notAccepted" ]]; then # No translation found
  notAccepted="License is not yet accepted!" # Fallback to English
fi  

### in die Validator-Zeile
###   "fn": "{var v=arguments[0]; if (!v) return 'Noch nicht akzeptiert!'; return true;}"
### die landessprachliche Übersetzung einfügen!
sed -i -e "s|@notAccepted@|$notAccepted|" "$SYNOPKG_TEMP_LOGFILE"

# Fill ComboBox with the configured scheduled Tasks:
# not possible as the command $(synoschedtask --get) is not working as actual user = $SYNOPKG_PKGNAME

logInfo 7 "Wizzard template '$JSON' copied to '$SYNOPKG_TEMP_LOGFILE' and values from config inserted"
logInfo 7 " ... ${BASH_SOURCE[0]} done"
exit 0
# next steps will be: Wizzard execution
#                     start-stop prestop, start-stop stop of old package if it's an upgrade
#                     preupgrade (optional)
#                     preuninst and postuninst from old package if it's an upgrade
#                     prereplace ??
#                     preinst

