#!/bin/bash

# Import config.conf
[[ -e ./config.conf ]] && . ./config.conf
[[ -e status/status.jpg ]] && : > status/status.jpg

prev_frame="$(<./fb/frameiterator)"
if [[ "${prev_frame}" =~ [0-9]*\.[0-9] ]]; then
	prev_frame="${prev_frame%.*}"
fi
time_started="$(TZ='Asia/Tokyo' date)"

# Main Loop
for ((i=1;i<=fph;i++)); do
    bash ./frameposter.sh "${1}" "${2}" || bash img_process.sh "failed" "${time_started}" || exit 1
    sleep "$((mins * 60))"
done

lim_frame="$(<./fb/frameiterator)"
[[ "${lim_frame%.*}" -gt "${total_frame}" ]] && lim_frame="${total_frame}"
[[ "${prev_frame}" -gt "${total_frame}" ]] && prev_frame="${total_frame}"

time_ended="$(TZ='Asia/Tokyo' date)"
ovr_all="$(sed -E ':L;s=\b([0-9]+)([0-9]{3})\b=\1,\2=g;t L' counter_n.txt)"
abt_txt="$(printf '%s\n%s\n%s' "3.5 FPS｜10 frames / 4 hrs" "→ ${ovr_all} frames was successfully posted" "WIKI: https://bit.ly/btrframes_wiki")"
bash img_process.sh "success" "${prev_frame}" "${lim_frame}" "${time_started}" "${time_ended}"
curl -sLk -X POST "https://graph.facebook.com/me/?access_token=${1}" --data-urlencode "about=${abt_txt}" -o /dev/null || true
