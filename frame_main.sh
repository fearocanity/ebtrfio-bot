#!/bin/bash

# Import config.conf
[[ -e ./config.conf ]] && . ./config.conf
[[ -e status/status.jpg ]] && : > status/status.jpg

prev_frame="$(<./fb/frameiterator)"
time_started="$(TZ='Asia/Tokyo' date)"

# Main Loop
for ((i=1;i<=fph;i++)); do
    bash ./frameposter.sh "${1}" "${2}" || exit 1
    sleep "$((mins * 60))"
done

time_ended="$(TZ='Asia/Tokyo' date)"
convert -fill white -background "darkgreen" -gravity center -pointsize 72 -font "trebuc.ttf" label:"\ [√] Frame ${prev_frame}-$((prev_frame+fph-1)) was posted " -pointsize 25 label:"Time started: ${time_started}\nTime ended: ${time_ended}" -append -bordercolor "darkgreen" -border 30 status/status.jpg
