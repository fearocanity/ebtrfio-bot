#!/bin/bash

# ############# #
# Author: EBTRFIO
# Date: Dec. 10 2022
# Licence: None
# Version: v1.2.1.2
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

scrv3(){
	# This function solves the timings of Subs
	# Set the current time variable
	current_time="${1}"
	hrs="${current_time%%:*}"
	mins="${current_time%:??.??}"
	mins="${mins/*:/}"

	# Convert the current time to seconds
	IFS=':.' read -r h m s ms <<< "$current_time"
	current_time_seconds="$((10#$h * 3600 + 10#$m * 60 + 10#$s + 10#$ms / 100)).$ms"

	# Scrape the time of the subtitle
	while IFS='×' read -r start_time end_time speaker subtitle; do
	    IFS=':.' read -r h m s ms <<< "$start_time"
	    start_time_seconds="$((10#$h * 3600 + 10#$m * 60 + 10#$s + 10#$ms / 100)).$ms"
	    IFS=':.' read -r h m s ms <<< "$end_time"
	    end_time_seconds="$((10#$h * 3600 + 10#$m * 60 + 10#$s + 10#$ms / 100)).$ms"
	    # Check if the current time is between the start and end time
	    if awk -v a="$current_time_seconds" -v b="$start_time_seconds" 'BEGIN{{if(a>=b) exit 0;exit 1}}' && awk -v a="$current_time_seconds" -v b="$end_time_seconds" 'BEGIN{{if(a<=b) exit 0;exit 1}}'; then
	        # Strip the stylings and display the subtitle
	        subtitle="${subtitle/\{*\}/}"
	        subtitle="${subtitle/\\N/}"
	        if [[ "${speaker}" =~ [^\,]*\,sign ]]; then
	            message_craft="【$(sed -E 's_[[:blank:]]{3}_ _g;s_\!([a-zA-Z0-9])_\! \1_g' <<< "${subtitle}")】
${message_craft}"
	        elif [[ "${speaker}" =~ Signs\,\, ]]; then
	            message_craft="\"$(sed -E 's_[[:blank:]]{3}_ _g;s_\!([a-zA-Z0-9])_\! \1_g' <<< "${subtitle}")\"
${message_craft}"
	        elif [[ "${speaker}" =~ Songs_OP\,OP ]]; then
	            is_opsong="1"
	            message_craft="『$(sed -E 's_[[:blank:]]{3}_ _g;s_\!([a-zA-Z0-9])_\! \1_g' <<< "${subtitle}")』
${message_craft}"
	        else
	            message_craft="${subtitle}
${message_craft}"
	        fi
	    fi
	done < <(sed -nE "/Dialogue:.*0,${hrs}:${mins}:??.??/"' s_.*\,([^\,]*),([^\,]*),(.*,[^\,]*,)0000,0000,0000,,(.*)_\1×\2×\3×\4_p' subtitle.ass)
	message_craft_a="$(grep -E '^【.+】$' <<< "${message_craft}")"
	message_craft_b="$(grep -vE '^【.+】$' <<< "${message_craft}")"
	message_craft="${message_craft_b}
${message_craft_a}"
	message_craft="$(sed '/^[[:blank:]]*$/d;/^$/d' <<< "${message_craft}" | sed '1!G;h;$!d' | uniq)"
	[[ -z "${message_craft}" ]] && is_empty="1" || is_empty="0"
	unset current_time_seconds start_time_seconds end_time_seconds start_time end_time speaker subtitle message_craft_a message_craft_b
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
scrv3 "$(nth "${prev_frame}")"

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
