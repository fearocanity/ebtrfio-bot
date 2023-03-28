#!/bin/bash

# Import config.conf
[[ -e ./config.conf ]] && . ./config.conf
[[ -e status/status.jpg ]] && : > status/status.jpg

prev_frame="$(<./fb/frameiterator)"
time_started="$(TZ='Asia/Tokyo' date)"

# Main Loop
for ((i=1;i<=fph;i++)); do
    bash ./frameposter.sh "${1}" "${2}" || bash img_process.sh "failed" "${time_started}" || exit 1
    sleep "$((mins * 60))"
done

lim_frame="$((prev_frame+fph-1))"
[[ "${lim_frame}" -gt "${total_frame}" ]] && lim_frame="${total_frame}"
[[ "${prev_frame}" -gt "${total_frame}" ]] && prev_frame="${total_frame}"

time_ended="$(TZ='Asia/Tokyo' date)"
ovr_all="$(LC_NUMERIC=en_US printf "%'.f\n" "$(<./counter_n.txt)")"
abt_txt="$(printf '%s\n%s' "Chopped 3.5 FPS, Posting 15 Frames every 2 hours." "Total of \"${ovr_all}\" frame was successfully posted!!")"
bash img_process.sh "success" "${prev_frame}" "${lim_frame}" "${time_started}" "${time_ended}"
curl -sLk -X POST "https://graph.facebook.com/me/?access_token=${1}" --data-urlencode "about=${abt_txt}" -o /dev/null || true