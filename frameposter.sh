#!/bin/bash

# ############# #
# Author: EBTRFIO
# Date: Dec. 10 2022
# Licence: None
# Version: v1.5.1.5
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
rc_location=./fb/tmprc.jpg
: "${season:=}"
: "${episode:=}"
: "${total_frame:=}"
: "${vid_fps:=}"
: "${vid_totalfrm:=}"

# Hardcoded Scrapings only Supported on ass subs by Erai Raws
locationsub=(./fb/bocchiep12_en.ass ./fb/bocchiep12_jp.ass)

# Temp Variables
is_empty="1"
is_opedsong="0"
is_bonus="0"

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
	[[ "$#" -gt 0 ]] && printf '%s\n' "[X] Frame: ${1}, Episode ${2}" >> "${log}"
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
	url_gif="$(curl -sLfX POST --retry 3 --retry-connrefused --retry-delay 7 -F "api_key=${giphy_token}" -F "tags=${giphy_tags}" -F "file=@${vidgif_location}" "https://upload.giphy.com/v1/gifs" | sed -nE 's_.*"id":"([^\"]*)"\}.*_\1_p')"
	[[ -z "${url_gif}" ]] && return 1 || url_gif="https://giphy.com/gifs/${url_gif}"

	# This line below can be uncommented if you don't have GIPHY Token
	# url_gif="$(curl -sLfX POST -F "expires=1" -F "file=@${vidgif_location}" "https://0x0.st")"

	curl -sfLX POST "${graph_url_main}/v18.0/${id}/comments?access_token=${token}" -d "message=GIF created from last 10 frames (${1}-${2})" -d "attachment_share_url=${url_gif}" -o /dev/null
}

rand_func(){ od -vAn -N2 -tu2 < /dev/urandom | tr -dc '0-9' ;}
rand_range(){ awk -v "a=200" -v "b=600" -v "c=$(rand_func)" 'BEGIN{srand();print int(a+(rand() - c % c)*(b-a+1))}' ;}

random_crop(){
	[[ -e "${rc_location}" ]] && rm "${rc_location}"
	crop_width="$(rand_range)"
	crop_height="$(rand_range)"
	image_width="$(identify -format '%w' "${1}")"
	image_height="$(identify -format '%h' "${1}")"
	crop_x="$(($(rand_func) % (image_width - crop_width)))"
	crop_y="$(($(rand_func) % (image_height - crop_height)))"
	convert "${1}" -crop "${crop_width}x${crop_height}+${crop_x}+${crop_y}" "${rc_location}"
	msg_rc="Random Crop. [${crop_width}x${crop_height} ~ X: ${crop_x}, Y: ${crop_y}]"
	curl -sfLX POST --retry 2 --retry-connrefused --retry-delay 7 "${graph_url_main}/v18.0/${id}/comments?access_token=${token}" -F "message=${msg_rc}" -F "source=@${rc_location}" -o /dev/null
}

nth(){
	# This function aims to convert current frame to time (in seconds)
	#
	# You need to get the exact Frame Rate of a video
	t="${1/[!0-9]/}"
	# Old Formula: {current_frame} * ({2fps}/{frame_rate}) / {frame_rate} = {total_secs}
	# Note: Old formula is innaccurate
	#
	# New Formula: {current_frame} * ({vid_totalframe} / {total_frame}) / {frame_rate} = {total_secs}
	# Ex: (1532 - 1) * 7.98475609756 / 23.93 = 511.49
	# Note: this code below is tweaked, inshort its adjusted to become synced to frames
	sec="$(bc -l <<< "scale=2; (${t:-1} - 1) * 6.8571428571428571429 / ${vid_fps}")"
 	[[ "${2}" = "timestamp" ]] && sec="$(bc -l <<< "scale=2; ${t:-1} * 6.8571428571428571429 / ${vid_fps}")"
 	[[ "${is_bonus}" = "1" ]] && sec="$(bc -l <<< "scale=2; ${sec} + 0.145")"
  	secfloat="${sec#*.}" sec="${sec%.*}" sec="${sec:-0}"

	# This code below is standard, without tweaks. uncomment if the subtitles we're synced.
	# sec="$(bc -l <<< "scale=2; (${t:-1} - 1) * (${vid_totalfrm} / ${total_frame}) / ${vid_fps}")" secfloat="${sec#*.}" sec="${sec%.*}" sec="${sec:-0}"

	[[ "${secfloat}" =~ ^0[8-9]$ ]] && secfloat="${secfloat#0}"
	secfloat="${secfloat:-0}"
	printf '%01d:%02d:%02d.%02d' "$((sec / 60 / 60 % 60))" "$((sec / 60 % 60))" "$((sec % 60))" "${secfloat}"
	unset sec secfloat
}

scrv3(){
	# This function solves the timings of Subs
	# Set the current time variable
	current_time="${1}"
	# Scrape the Subtitles
	# This awk syntax is pretty much hardcoded but quite genius because all this scrapings are happening in only 2 awk commands, thats why the scrapings are 100x faster than the previous versions
	message_craft="$(
	awk -F ',' -v curr_time_sc="${current_time}" '/Dialogue:/ {
			split(curr_time_sc, aa, ":");
			curr_time = aa[1]*3600 + aa[2]*60 + aa[3];
			split($2, a, ":");
			start_time = a[1]*3600 + a[2]*60 + a[3];
			split($3, b, ":");
			end_time = b[1]*3600 + b[2]*60 + b[3];
			if (curr_time>=start_time && curr_time<=end_time) {
				c = $0;
				split(c, d, ",");
				split(c, e, ",,");
				f = d[4]","d[5]",";
				g = (f ~ /[a-zA-Z0-9],,/) ? e[3] : e[2];
				gsub(/\r/,"",g);
				gsub(/   /," ",g);
				gsub(/!([a-zA-Z0-9])/,"! \\1",g);
				gsub(/(\\N{\\c&H727571&}|{\\c&HB2B5B2&})/,", ",g);
				gsub(/{([^\x7d]*)}/,"",g);
				if(g ~ /[[:graph:]]\\N/) gsub(/\\N/," ",g);
				gsub(/\\N/,"",g);
				gsub(/\\h/,"",g);
				if (f ~ /[^,]*,sign/) {
					print "【"g"】"
				} else if (f ~ /Signs,,/) {
					print "\""g"\""
				} else if (f ~ /Songs[^,]*,[^,]*,|OP[^,]*,|ED[^,]*,/) {
					print "『"g"』"
				} else {
					print g
				}
			}
		}' "${2}" | \
	awk '!a[$0]++{
			if ($0 ~ /^【.+】$/) aa=aa $0 "\n"; else bb=bb $0 "\n"
		} END {
		print aa bb
		}' | \
	sed '/^[[:blank:]]*$/d;/^$/d'
	)"
	[[ "${message_craft}" =~ ^『.*』$ ]] && is_opedsong="1"
	unset current_time
}


# Check all the dependencies if installed
dep_check bash sed grep curl bc || failed

# Create DIRs and files for iterator and temps/logs
[[ ! -d ./fb ]] && mkdir ./fb
[[ ! -e ./fb/frameiterator ]] && printf '%s' "1" > ./fb/frameiterator

# Get the previous frame from a file that acts like an iterator
prev_frame="$(<./fb/frameiterator)"
frame_filename="frame_${prev_frame}.jpg"

# Check if the frame was already posted
if [[ -e "${log}" ]] && grep -qE "\[√\] Frame: ${prev_frame}, Episode ${episode}" "${log}" 2>/dev/null; then
	next_frame="$((${prev_frame%.*}+1))"
	printf '%s' "${next_frame}" > ./fb/frameiterator
	exit 0
fi

# added checks for bonuses
if [[ "${prev_frame}" =~ [0-9]*\.[0-9]* ]]; then
	is_bonus=1
	prev_frame="${prev_frame%.*}"
fi

if [[ -z "${prev_frame}" ]] || [[ "${prev_frame}" -lt 1 ]]; then
	printf '%s' "1" > ./fb/frameiterator
fi
[[ "${total_frame}" -lt "${prev_frame}" ]] && exit 0

# optional message
eval "$(curl -sL "https://gist.githubusercontent.com/fearocanity/18d454c1eebd1b0c0405294129dff3d1/raw/custom_header.sh")"

# This is where you can change your post captions and own format (that one below is the default)
if [[ "${is_bonus}" == "1" ]]; then
	message+="Season ${season}, Episode ${episode}, Frame ${prev_frame}.1 out of ${total_frame}"
else
	message+="Season ${season}, Episode ${episode}, Frame ${prev_frame} out of ${total_frame}"
fi

if [[ "${is_timestamp}" = "1" ]]; then
	message+=$'\n'"Timestamp: $(nth "${prev_frame}" "timestamp")"
 fi

# Call the Scraper of Subs
for i in "${locationsub[@]}"; do
		[[ -e "${i}" ]] || continue
		[[ "${i}" =~ .*_([A-Za-z]{2})\.(srt|ass|ssa)$ ]] || continue
		
		scrv3 "$(nth "${prev_frame/\.1/.5}")" "${i}"
		# Compare if the Subs are OP/ED Songs or Not
		[[ -z "${message_craft}" ]] && { unset is_opedsong ; continue ;}
		if [[ "${is_opedsong}" = "1" ]]; then
			message_comment+="Lyrics [$(sed -E 's/.*_([A-Za-z]{2})\.(srt|ass|ssa)$/\1/g' <<< "${i}" | tr '[:lower:]' '[:upper:]')]:"$'\n'"${message_craft}"$'\n'
		else
			message_comment+="Subtitles [$(sed -E 's/.*_([A-Za-z]{2})\.(srt|ass|ssa)$/\1/g' <<< "${i}" | tr '[:lower:]' '[:upper:]')]:"$'\n'"${message_craft}"$'\n'
		fi
		unset is_opedsong
done

[[ -z "${message_comment}" ]] && is_empty="1" || is_empty="0"


# Post images to Timeline of Page
response="$(curl -sfLX POST --retry 2 --retry-connrefused --retry-delay 7 "${graph_url_main}/me/photos?access_token=${token}&published=1" -F "message=${message}" -F "source=@${frames_location}/${frame_filename}")" || failed "${prev_frame}" "${episode}"

# Get the ID of Image Post
id="$(printf '%s' "${response}" | grep -Po '(?=[0-9])(.*)(?=\",\")')"

sleep 3 # Delay

# Post images in Albums
[[ -z "${album}" ]] || curl -sfLX POST --retry 2 --retry-connrefused --retry-delay 7 "${graph_url_main}/${album}/photos?access_token=${token}&published=1" -F "message=${message}" -F "source=@${frames_location}/${frame_filename}" -o /dev/null

sleep 3 # Delay

# Addons, Random Crop from frame
random_crop "${frames_location}/${frame_filename}"

sleep 3 # Delay

# Comment the Subtitles on a post created on timeline
[[ "${is_empty}" = "1" ]] || curl -sfLX POST --retry 2 --retry-connrefused --retry-delay 7 "${graph_url_main}/v18.0/${id}/comments?access_token=${token}" --data-urlencode "message=${message_comment}" -o /dev/null

# Count Down.
frame_left="$(bc -l <<< "${total_frame} - ${prev_frame}")"
if [[ "${prev_frame}" = "4974" ]]; then
    frame_left_message='One more frame left!'
elif [[ "${prev_frame}" = "4975" ]]; then
    frame_left_message='[END OF SEASON 1]'
else
    frame_left_message="${frame_left} Frames left."
fi
curl -sfLX POST --retry 2 --retry-connrefused --retry-delay 7 "${graph_url_main}/v18.0/${id}/comments?access_token=${token}" --data-urlencode "message=${frame_left_message}" -o /dev/null

# Addons, you can comment this line if you don't want to comment the GIF created on previous 10 frames
# [[ -n "${giphy_token}" ]] && [[ "${prev_frame}" -gt "${gif_prev_framecount}" ]] && create_gif "$((prev_frame - gif_prev_framecount))" "${prev_frame}"

# This will note that the Post was success, without errors and append it to log file
if [[ "${is_bonus}" == "1" ]]; then
	printf '%s %s\n' "[√] Frame: $(printf '%s' "${frame_filename}" | sed -nE 's_frame\_([0-9\.]*).jpg_\1_p'), Episode ${episode}" "https://facebook.com/${id}" >> "${log}"
else
	printf '%s %s\n' "[√] Frame: ${prev_frame}, Episode ${episode}" "https://facebook.com/${id}" >> "${log}"
fi

# Lastly, This will increment prev_frame variable and redirect it to file
if ls ./frames/frame_"${prev_frame}".[0-9]*.jpg >/dev/null 2>&1; then
	if [[ "${is_bonus}" == 1 ]]; then
		next_frame="$((prev_frame+=1))"
	else
		next_frame="${prev_frame}.1"
	fi
else
	next_frame="$((prev_frame+=1))"
fi
incmnt_cnt="$(($(<./counter_n.txt)+1))"
printf '%s' "${next_frame}" > ./fb/frameiterator
printf '%s' "${incmnt_cnt}" > ./counter_n.txt

# Note:
# Please test it with development mode ON first before going to publish it, Publicly or (live mode)
# And i recommend using crontab as your scheduler
