#!/bin/bash
#shellcheck disable=2034,1091 # no warning for unused variables, not found external scripts like pkg_util.sh
if [[ "$1" == "" ]]; then # Generation with toolkit scripts
  source /pkgscripts-ng/include/pkg_util.sh
fi
package="callmonitor"
displayname="Call Monitor"  # if not set then $package will be used as displayname
displayname_enu="Call Monitor" #  displayname_<lng> for the INFO file will be fetched from lang.txt file entry displaynameINFO
displayname_ger="Call Monitor"
description="Synchronize system variables of HomeMatic CCU with the Phone Line Status from a FritzBox and generate call lists"
# description_<lng> for the INFO file will be fetched from lang.txt file entry descriptionINFO:
description_enu="Synchronize system variables of HomeMatic CCU with the Phone Line Status from a FritzBox and generate call lists"
description_ger="Systemvariablen der HomeMatic CCU mit dem Telefon-Leitungsstatus der FritzBox synchron halten. Und Anruflisten erzeugen."

version="0.0.1-0003"
beta="yes"
arch="noarch"
os_min_ver="7.0-40000"
# install_dep_packages="WebStation>=3.0.0-0323:PHP7.4>=7.4.18-0114:Apache2.4>=2.4.46-0122"
install_dep_packages="Perl" # needed!
maintainer="Horst Schmid"
maintainer_url="https://github.com/schmidhorst/synology-callmonitor"
# ctl_stop="yes"
# reloadui="yes"
thirdparty="yes"
support_center="no"
dsmuidir="ui"
distributor=""
# distributor_url=""
silent_upgrade="no"
# silent_install="no"
# precheckstartstop="yes"
# helpurl="https://..."
support_url="https://github.com/schmidhorst/synology-${package}/issues"
dsmappname="SYNO.SDS._ThirdParty.App.$package"
# shellcheck disable=SC2164
SCRIPTPATHinfo="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"

# index.cgi uses https://raw.githubusercontent.com/schmidhorst/synology-<appname>/main/INFO.sh to check for an new version
# change that entry automatically if the maintainer_url is changed:
if [[ -n "$maintainer_url" ]]; then
  githubRawInfoUrl=$(echo "${maintainer_url}/main/INFO.sh" | sed 's/github.com/raw.githubusercontent.com/')
  # patch githubRawInfoUrl directly to the index.cgi file if necessary:
  lineInfoUrl=$(grep "githubRawInfoUrl=" "$SCRIPTPATHinfo/package/$dsmuidir/index.cgi")
  if [[ "$lineInfoUrl" != "githubRawInfoUrl=\"${githubRawInfoUrl}\"" ]]; then
    sed -i "s|^githubRawInfoUrl=.*\$|githubRawInfoUrl=\"${githubRawInfoUrl}\" #patched to distributor_url from INFO.sh|" "$SCRIPTPATHinfo/package/$dsmuidir/index.cgi"
  fi
fi
if [[ "$1" != "" ]]; then  # Generation without toolkit scripts
  line0=$(grep "SYNO.SDS." "package/$dsmuidir/config")
  # echo "from ui/config: '$line0'"
  line1="${line0#*SYNO.SDS.}"
  line1=${line1%%\"*}
  dsmappname="SYNO.SDS.${line1}" # synodsmnotify works only, if dsmappname is identical to .url in ui/config !
  pck=${line1##*.}
  if [[ "$pck" != "$package" ]]; then
    echo "================================================================"
    echo "==INFO.sh: ====================================================="
    echo "Warning: package='$package' not found in .url{...} of package/$dsmuidir/config:"
    echo "$line0"
    echo "================================================================"
    echo "================================================================"
  fi

  line0=$(grep -i '"appWindow"' "package/$dsmuidir/config")
  # echo "from ui/config: '$line0'"
  if [[ -n "$line0" ]] && [[ ! "${line0,,}" == *"${package,,}"* ]]; then # match in lower case
    echo "================================================================"
    echo "==INFO.sh: ====================================================="
    echo "Warning: The \"appWindow\" line in package/$dsmuidir/config does not contain the package name '$package':"
    echo "$line0"
    echo "================================================================"
    echo "================================================================"
  fi

  line0=$(grep -i '"url"' "package/$dsmuidir/config")
  # echo "from ui/config: '$line0'"
  if [[ -n "$line0" ]] && [[ "$line0" == *"/webman/3rdparty/"* ]] && [[ ! "${line0,,}" == *"${package,,}"* ]]; then # match in lower case
    echo "================================================================"
    echo "==INFO.sh: ====================================================="
    echo "Warning: The \"url\" line in package/$dsmuidir/config does not contain the package name '$package':"
    echo "$line0"
    echo "================================================================"
    echo "================================================================"
  fi

  line0=$(grep -i '"app"' "package/$dsmuidir/index.conf")
  # echo "from ui/index.conf: '$line0'"
  if [[ -n "$line0" ]] && [[ ! "${line0,,}" == *"${package,,}"* ]]; then # match in lower case
    echo "================================================================"
    echo "==index.conf: ====================================================="
    echo "Warning: The \"app\" line in package/$dsmuidir/index.conf does not contain the package name '$package':"
    echo "$line0"
    echo "================================================================"
    echo "================================================================"
  fi

  line0=$(grep -i '"title"' "package/$dsmuidir/index.conf")
  # echo "from ui/index.conf: '$line0'"
  if [[ -n "$line0" ]] && [[ ! "${line0,,}" == *"${package,,}"* ]]; then # match in lower case
    echo "================================================================"
    echo "==index.conf: ====================================================="
    echo "Warning: The \"title\" line in package/$dsmuidir/index.conf does not contain the package name '$package':"
    echo "$line0"
    echo "================================================================"
    echo "================================================================"
  fi

  # Option:
  # - Check for all $dsmuidir/*_<lng>.html files whether a <title>...</title> line contains displaynameINFO from <lng>/lang.txt
  # - Check if a $dsmuidir/*_.html file contains *"https://github.com/"* the match to maintainer_url from INFO/INFO.sh

fi # Generation without toolkit scripts

# Creation of the File INFO in the actual folder during spk package building:
if [[ "$1" != "" ]]; then # Generation without toolkit scripts
# copy of 'pkg_dump_info' from '/pkgscripts-ng/include/pkg_util.sh' ('local' removed):
  langs="enu chs ger fre ita spn jpn dan sve nld rus plk ptb ptg hun trk csy" # cht, krn, nor: not supported by DeepL, ptb?

  fields="package version maintainer maintainer_url distributor distributor_url arch exclude_arch model exclude_model
    adminprotocol adminurl adminport firmware dsmuidir dsmappname dsmapppage dsmapplaunchname checkport allow_altport
    startable helpurl report_url support_center install_reboot install_dep_packages install_conflict_packages install_dep_services
    instuninst_restart_services startstop_restart_services start_dep_services silent_install silent_upgrade silent_uninstall install_type
    checksum package_icon package_icon_120 package_icon_128 package_icon_144 package_icon_256 thirdparty support_conf_folder
    auto_upgrade_from offline_install precheckstartstop os_min_ver os_max_ver beta ctl_stop ctl_install ctl_uninstall
    install_break_packages install_replace_packages use_deprecated_replace_mechanism description displayname"
  # local f=

  echo "Generating INFO file .."
  for f in $fields; do
    if [ -n "${!f}" ]; then  # indirect addressing with ! for f
      echo "  $f=\"${!f}\""
      echo "$f=\"${!f}\"" >> INFO
    fi
  done
  echo "... INFO file done!"
fi

# For all configured languages:
#   Setup of description_<lng> and displayname_<lng> in INFO file from <lng>/lang.txt file entries descriptionINFO and displaynameINFO
lngFolder="$SCRIPTPATHinfo/package/$dsmuidir/texts"
for lang in $langs; do
  descriptionINFO=""
  displaynameINFO=""
  if [[ -f "$lngFolder/$lang/lang.txt" ]]; then

    eval "$(grep "descriptionINFO=" "$lngFolder/$lang/lang.txt")"
    description="description_${lang}"
    if [ -n "${descriptionINFO}" ]; then
      echo "${description}=\"${descriptionINFO}\"" >> INFO
      if [[ "$lang" == "enu" ]]; then
        echo "description=\"${descriptionINFO}\"" >> INFO
      fi
    fi
    eval "$(grep "displaynameINFO=" "$lngFolder/$lang/lang.txt")"
    displayname="displayname_${lang}"
    if [ -n "${displaynameINFO}" ]; then
      echo "${displayname}=\"${displaynameINFO}\"" >> INFO
      if [[ "$lang" == "enu" ]]; then
        echo "displayname=\"${displaynameINFO}\"" >> INFO
      fi
    fi
  fi
done

if [[ "$1" != "" ]]; then # Generation without toolkit scripts
  # build.sh will append a line with e.g. create_time="2025-03-07 21:46:38"
  # checksum  MD5 string to verify the package.tgz.
  return 0
fi

# Generation with toolkit:
[ "$(caller)" != "0 NULL" ] && return 0

if [[ "$1" == "" ]]; then
  pkg_dump_info
else
  echo "INFO.sh Error: pkg_dump_info not executed!"
  echo "pwd=$(/bin/pwd)"
  echo "ls -l: '$(ls -l)'"
fi

