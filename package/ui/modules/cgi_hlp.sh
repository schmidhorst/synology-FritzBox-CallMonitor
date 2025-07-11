#!/bin/bash

logfileOutput() { # Parameter: file name incl. path
  while IFS=$'\n' read -r line; do # read all items from logfile
    # split the line now at an tab character (default) or at ": " (if no tab char found, old/obsolete)
    rest1="${line#*: }"
    # rest2="${line#*\t}" not working
    rest2=$(sed 's/[^\t]*\t//' <<<"$line")
    p1=$((${#line} - ${#rest1} - 2 ))
    p2=$((${#line} - ${#rest2} - 1 ))
    if [[ "$p1" -lt 0 ]]; then p1="9999"; fi
    if [[ "$p2" -lt 0 ]]; then p2="9999"; fi
    if [[ "$p1" -eq 9999 ]] && [[ "$p2" -eq 9999 ]]; then
      timestamp=""  # neither tab char nor ': ' found ==> put all to 2nd column
      msg="$line"
    else
      # split line to two columns:
      if [[ "$p1" -gt "$p2" ]]; then # use TAB
        p1="$p2"
        p2=$((p1+1))
      else
        p2=$((p1+2))
      fi
      timestamp="${line:0:p1}"
      msg="${line:p2}"
    fi
    echo "<tr><td>$timestamp</td><td>$msg</td></tr>"
  done < "$1" # Works well even if last line has no \n!
  }


linkedFileSize() {
  filesize_Bytes=0
  if linkTarget="$(readlink "$1")"; then # result 1 if it's not a link
    filesize_Bytes=$(stat -c%s "$linkTarget")
    # lineCount=$(wc -l < "$linkTarget")
  else
    # shellcheck disable=SC2034
    filesize_Bytes=$(stat -c%s "$1")  # if it's a link this returns size of the link, not of linked file!
    # lineCount=$(wc -l < "$1")
  fi
  echo "$filesize_Bytes"
  }
