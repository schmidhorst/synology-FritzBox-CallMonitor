#!/bin/bash
# shellcheck disable=SC2164
SCRIPTPATHwiz="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
if [[ -f "${SCRIPTPATHwiz}/log_hlp.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPTPATHwiz}/log_hlp.sh"
else
  echo "Error: '${SCRIPTPATHwiz}/log_hlp.sh' not found!" 1>&2
  exit 1
fi
logInfo 2 "Attention: Environment variable SYNOPKG_PKGVER=$SYNOPKG_PKGVER is wrong! SYNOPKG_OLD_PKGVER=$SYNOPKG_OLD_PKGVER is o.k!"
logInfo 7 "$SCRIPTPATHwiz/upgrade_uifile.sh started ..."
# shellcheck disable=SC1091
source "$SCRIPTPATHwiz/uifile.sh" "upgrade"
logInfo 7 "... $SCRIPTPATHwiz/upgrade_uifile.sh done!"
