#!/bin/bash
# Filename: permissions.sh - coded in utf-8
# call: /usr/syno/synoman/webman/3rdparty/callmonitor/permissions.sh
#   or  /var/packages/callmonitor/target/ui/permissions.sh


#                     LogAnalysis for DSM 7
#
#        Copyright (C) 2025 by Tommes | License GNU GPLv3
#        Member from the  German Synology Community Forum
#        Adopted to callmonitor by Horst Schmid
#
# Extract from  GPL3   https://www.gnu.org/licenses/gpl-3.0.html
#                                     ...
# This program is free software: you can redistribute it  and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# See the GNU General Public License for more details.You should
# have received a copy of the GNU General Public  License  along
# with this program. If not, see http://www.gnu.org/licenses/  !

app_name="callmonitor"
groupname="administrators" # der Gruppe users kann kein Account hinzugefügt werden!

# Funktion: Benutzer einer Gruppe hinzufügen oder entfernen
# --------------------------------------------------------------
# Aufruf: synogroupuser "[adduser or deluser]" "GROUP" "USER"
function synogroupuser()
{
	oldIFS=${IFS}
	IFS=$'\n'
	query=${1}
	group=${2}
	user=${3}
	userlist=$(synogroup --get "${group}" | grep -E '^[0-9]*:'| sed -e 's/^[0-9]*:\[\(.*\)\]/\1/')
	updatelist=()
	for i in ${userlist}; do
		if [[ "${query}" == "adduser" ]]; then
			[[ "${i}" != "${user}" ]] && updatelist+=("${i}")
			[[ "${i}" == "${user}" ]] && userexists="true"
		elif [[ "${query}" == "deluser" ]]; then
			[[ "${i}" != "${user}" ]] && updatelist+=("${i}")
			[[ "${i}" == "${user}" ]] && userexists="true"
		else
			synodsmnotify -c SYNO.SDS.${app_name}.Application @administrators ${app_name}:app:app_name ${app_name}:app:groupuser_error
			exit 1
		fi
	done

	if [[ -z "${userexists}" && "${query}" == "adduser" ]]; then
		updatelist+=("${user}")
		res=$(synogroup --member "${group}" "${updatelist[@]}")
    ret=$?
    echo "ret=$ret, res=$res"
		synodsmnotify -c SYNO.SDS._ThirdParty.App.${app_name} @administrators ${app_name}:app1:title1 ${app_name}:app1:perm_add_true "$app_name" "$group"
		synologset1 sys info 0x11100000 "Package [${app_name}] has successfully expanded app permissions!"
	elif [[ -n "${userexists}" && "${query}" == "adduser" ]]; then
		synodsmnotify -c SYNO.SDS.${app_name}.Application @administrators ${app_name}:app1:title1 ${app_name}:app1:perm_add_exists "$app_name" "$group"
		exit 2
	elif [[ -n "${userexists}" && "${query}" == "deluser" ]]; then
		synogroup --member "${group}" "${updatelist[@]}"
		synodsmnotify -c SYNO.SDS.${app_name}.Application @administrators ${app_name}:app1:title1 ${app_name}:app1:perm_del_true "$app_name" "$group"
		synologset1 sys info 0x11100000 "Package [${app_name}] has successfully revoked advanced app permissions!"
	elif [[ -z "${userexists}" && "${query}" == "deluser" ]]; then
		synodsmnotify -c SYNO.SDS.${app_name}.Application @administrators ${app_name}:app1:title1 ${app_name}:app1:perm_del_notexist "$app_name" "$group"
		exit 3
	fi
	IFS=${oldIFS}
}

# Setzt App Berechtigungen
# ----------------------------------------------------------------

	# Prüfe ob Version min. DSM 7 entspricht
	# -----------------------------------------------------------------
	if [ "$(synogetkeyvalue /etc.defaults/VERSION majorversion)" -ge 7 ]; then

		# app der Gruppe $groupname hinzufügen
		if [[ "${1}" == "adduser" ]]; then
			synogroupuser "adduser" "$groupname" "${app_name}"
		fi

		# app aus der Gruppe $groupname entfernen
		if [[ "${1}" == "deluser" ]]; then
			synogroupuser "deluser" "$groupname" "${app_name}"
		fi
	fi
