#!/bin/bash
LOG="/var/log/packages/callmonscript.log"
while [ -n "$1" ]; do
  printf "%s " "$1" >> "$LOG" 
  shift
done
printf "\n" >> "$LOG" 
