#!/bin/bash
LOG="/var/log/packages/callmonscript.log"
DTFMT="+%Y-%m-%d %H:%M:%S"
print "%s\t" "$(date "$DTFMT")" >> "$LOG"
while [ -n "$1" ]; do
  printf "%s\t" "$1" >> "$LOG" 
  shift
done
printf "\n" >> "$LOG" 
