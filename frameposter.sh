#!/bin/bash

# ############# #
# Author: EBTRFIO
# Date: Dec. 10 2022
# Licence: None
# Version: v1.1.1.2
# ############# #

# --- Dependencies --- #
# * bash
# * imgmagick (optional if GIF posting were enabled)
# * gnu sed
# * grep
# * curl
# * bc
# ############# #
[[ -e ./secrets.sh ]] && . ./secrets.sh
[[ -e ./config.conf ]] && . ./config.conf
# Invi Space (Space that actually bypass the blank character stripper of facebook)
# 　　　　　　　
# ^^^ Invi Space ^^^

# export PATH="$PATH:/usr/bin:/usr/sbin"

# opt variables
graph_url_main="https://graph.facebook.com"
frames_location=./frames
log=./fb/log.txt
vidgif_location=./fb/tmp.gif
: "${season:=}"
: "${episode:=}"
: "${total_frame:=}"
: "${vid_fps:=}"
: "${vid_totalfrm:=}"

# Hardcoded Scrapings only Supported on ass subs by Erai Raws
locationsub=./fb/bocchi_ep2.ass

# Temp Variables
is_empty="1"
is_opsong="0"

# These token variables are required when making request and auths in APIs
# Create secret.sh file to assign the token variable
# (e.g)
# fb_api_key="{your_api_key}"
# giphy_api_key="{your_api_key}"
#
# ###################### #
# or Supply Arguments in Github Workflows
# you must create your Environment Variables in Secrets
token="${1:-${fb_api_key}}"
giphy_token="${2:-${giphy_api_key}}"

failed(){
	printf '%s\n' "[X] Frame: ${1}, Episode ${2}" >> "${log}"
	exit 1
}

dep_check(){
	for deppack; do
		if ! command -v "${deppack}" >/dev/null ; then
			printf '%s\n' "[FATAL ERROR] Program \"${deppack}\" is not installed."
			is_err="1"
		fi
	done
	[[ "${is_err}" = "1" ]] && return 1
	return 0
}

create_gif(){
	dep_check convert | tee -a "${log}" || return 1
	[[ -e "${vidgif_location}" ]] && rm "${vidgif_location}"
	convert -resize "50%" -delay 20 -loop 1 $(eval "echo ${frames_location}/frame_{""${1}""..""${2}""}.jpg") "${vidgif_location}"
	
	# GIPHY API is Required when using this code
	url_gif="$(curl -sLfX POST --retry 3 --retry-connrefused --retry-delay 7 -F "api_key=${giphy_token}" -F "tags= ${giphy_tags}" -F "file=@${vidgif_location}" "https://upload.giphy.com/v1/gifs" | sed -nE 's_.*"id":"([^\"]*)"\}.*_\1_p')"
	[[ -z "${url_gif}" ]] && return 1 || url_gif="https://giphy.com/gifs/${url_gif}"
	
	# This line below can be uncommented if you don't have GIPHY Token
	# url_gif="$(curl -sLfX POST -F "expires=1" -F "file=@${vidgif_location}" "https://0x0.st")"
	
	curl -sfLX POST "${graph_url_main}/v15.0/${id}/comments?access_token=${token}" -d "message=GIF created from last 10 frames (${1}-${2})" -d "attachment_share_url=${url_gif}" -o /dev/null
}

toepoch(){
	# This function aims to compute 00:00:00.00 (time) to seconds
	hrs="${1%%:*}"
	mins="${1%:??.??}" mins="${mins/*:/}" mins="${mins##0}"
	secs="${1##*:}" milisecs="${secs#*.}" secs="${secs%%.*}" secs="${secs##0}"
	printf '%s' "$((hrs * 3600 + mins * 60 + secs)).${milisecs}"
	unset hrs mins secs milisecs
}

nth(){
	# This function aims to convert current frame to time (in seconds)
	#
	# You need to get the exact Frame Rate of a video
	# Old Formula: {current_frame} * ({2fps}/{frame_rate}) / {frame_rate} = {total_secs}
	# Note: Old formula is innaccurate
	#
	# New Formula: {current_frame} * ({vid_totalframe} / {total_frame}) / {frame_rate} = {total_secs}
	# Ex: (1532 - 1) * 7.98475609756 / 23.93 = 511.49
	# Note: this code below is tweaked, inshort its adjusted to become synced to frames
	sec="$(bc -l <<< "scale=2; (${1} - 2) * 7.98475609756 / ${vid_fps}")" secfloat="${sec#*.}" sec="${sec%.*}" sec="${sec:-0}"
	
	# This code below is standard, without tweaks. uncomment if the subtitles we're synced.
	# sec="$(bc -l <<< "scale=2; (${1} - 1) * (${vid_totalfrm} / ${total_frame}) / ${vid_fps}")" secfloat="${sec#*.}" sec="${sec%.*}" sec="${sec:-0}"
	
	[[ "${secfloat}" =~ ^0[8-9]$ ]] && secfloat="${secfloat#0}"
	secfloat="${secfloat:-0}"
	printf '%01d:%02d:%02d.%02d' "$((sec / 60 / 60 % 60))" "$((sec / 60 % 60))" "$((sec % 60))" "${secfloat}"
	unset sec secfloat
}

scr2(){
	# This function solves the timings of Subs
	a="$(toepoch "${1}")"
	subs_content="$(sed -E 's_Dialogue: [0-9],([0-9\:\,.]*),(.*),0000,0000,0000,,_\1€\2()_g;/\(\)/!d;s_(\\N\{\\c\&H727571\&\}|\{\\c\&HB2B5B2\&\})_, _g;s_\{([^\x7d]*)\}__g;/[[:graph:]]\\N/ s_\\N_ _g;s_\\N__g;s_\\h__g' "${locationsub}" | tr -d '\r')"
	[[ ! "${1%%:*}" =~ ^0*$ ]] && list="$(grep -E "${1%%:*}:[0-9]{2}:[0-9]{2}.[0-9]{2}" <<< "${subs_content}")"
	mins="${1%:??.??}" mins="${mins/*:/}"
	[[ -z "${list}" ]] && [[ ! "${mins}" =~ ^0*$ ]] && list="$(grep -E "0:$(printf '%s' "${1}" | cut -d':' -f2):[0-9]{2}.[0-9]{2}" <<< "${list:-${subs_content}}")"
	secs="${1##*:}" milisecs="${secs#*.}" secs="${secs%%.*}"
	[[ -z "${list}" ]] && list="${subs_content}"
	while read -r b; do
		start="$(toepoch "$([[ "${b}" =~ ^([^\,]*), ]] && printf '%s' "${BASH_REMATCH[1]}")")"
		end="$(toepoch "$([[ "${b}" =~ ,([^\€]*)€ ]] && printf '%s' "${BASH_REMATCH[1]}")")"
		if (( $(bc -l <<< "${a} >= ${start}") )) && (( $(bc -l <<< "${a} <= ${end}") )); then
			if [[ "${b}" =~ [^\,]*\,sign ]]; then
				message_craft="【$(sed -nE 's_[[:blank:]]{3}_ _g;s_\!([a-zA-Z0-9])_\! \1_g;s_.*\(\)(.*)_\1_p' <<< "${b}")】
${message_craft}"
			elif [[ "${b}" =~ Signs\,\, ]]; then
				message_craft="$(sed -nE 's_[[:blank:]]{3}_ _g;s_\!([a-zA-Z0-9])_\! \1_g;s_.*\(\)(.*)_"\1"_p' <<< "${b}")
${message_craft}"
			elif [[ "${b}" =~ Songs_OP\,OP ]]; then
				is_opsong="1"
				message_craft="『$(sed -nE 's_[[:blank:]]{3}_ _g;s_\!([a-zA-Z0-9])_\! \1_g;s_.*\(\)(.*)_\1_p' <<< "${b}")』
${message_craft}"
			else
				message_craft="${b/*\(\)/}
${message_craft}"
			fi
			continue
		fi
		(( $(bc -l <<< "${a} <= ${end}") )) && break
	done <<-EOF
	${list}
	EOF
	message_craft_a="$(grep -E '^【.+】$' <<< "${message_craft}")"
	message_craft_b="$(grep -vE '^【.+】$' <<< "${message_craft}")"
	message_craft="${message_craft_b}
${message_craft_a}"
	message_craft="$(sed '/^$/d' <<< "${message_craft}" | sed '1!G;h;$!d' | uniq)"
	[[ -z "${message_craft}" ]] && is_empty="1" || is_empty="0"
	unset list start end a b secs milisecs mins subs_content
}

# Check all the dependencies if installed
dep_check bash sed grep curl bc || exit 1

# Create DIRs and files for iterator and temps/logs
[[ ! -d ./fb ]] && mkdir ./fb
[[ ! -e ./fb/frameiterator ]] && printf '%s' "1" > ./fb/frameiterator
[[ -z "$(<./fb/frameiterator)" ]] && printf '%s' "1" > ./fb/frameiterator
[[ "${total_frame}" -lt "$(<./fb/frameiterator)" ]] && exit 0

# Get the previous frame from a file that acts like an iterator
prev_frame="$(<./fb/frameiterator)"

# Check if the frame was already posted
if [[ -e "${log}" ]] && grep -qE "\[√\] Frame: ${prev_frame}, Episode ${episode}" "${log}"; then
	next_frame="$((prev_frame+=1))"
	printf '%s' "${next_frame}" > ./fb/frameiterator
	exit 0
fi

# This is where you can change your post captions and own format (that one below is the default)
message="Season ${season}, Episode ${episode}, Frame ${prev_frame} out of ${total_frame}"

# Call the Scraper of Subs
scr2 "$(nth "${prev_frame}")"

# Compare if the Subs are OP Songs or Not
if [[ "${is_opsong}" = "1" ]]; then
	message_comment="Lyrics:
${message_craft}"
else
	message_comment="Subtitles:
${message_craft}"
fi

# Post images to Timeline of Page
response="$(curl -sfLX POST --retry 3 --retry-connrefused --retry-delay 7 "${graph_url_main}/me/photos?access_token=${token}&published=1" -F "message=${message}" -F "source=@${frames_location}/frame_${prev_frame}.jpg")" || failed "${prev_frame}" "${episode}"

# Get the ID of Image Post
id="$(printf '%s' "${response}" | grep -Po '(?=[0-9])(.*)(?=\",\")')"

# Post images in Albums
[[ -z "${album}" ]] || curl -sfLX POST --retry 3 --retry-connrefused --retry-delay 7  "${graph_url_main}/${album}/photos?access_token=${token}&published=1" -F "message=${message}" -F "source=@${frames_location}/frame_${prev_frame}.jpg" -o /dev/null &

# Comment the Subtitles on a post created on timeline
[[ "${is_empty}" = "1" ]] || curl -sfLX POST --retry 3 --retry-connrefused --retry-delay 7 "${graph_url_main}/v15.0/${id}/comments?access_token=${token}" --data-urlencode "message=${message_comment}" -o /dev/null &

# Addons, you can comment this line if you don't want to comment the GIF created on previous 10 frames
[[ -n "${giphy_token}" ]] && [[ "${prev_frame}" -gt "${gif_prev_framecount}" ]] && create_gif "$((prev_frame - gif_prev_framecount))" "${prev_frame}"

# This will note that the Post was success, without errors and append it to log file
printf '%s %s\n' "[√] Frame: ${prev_frame}, Episode ${episode}" "https://facebook.com/${id}" >> "${log}"

# Lastly, This will add + 1 to prev_frame variable and redirect it to file
next_frame="$((prev_frame+=1))"
printf '%s' "${next_frame}" > ./fb/frameiterator


# Note:
# Please test it with development mode ON first before going to publish it, Publicly or (live mode)
# And i recommend using crontab as your scheduler
