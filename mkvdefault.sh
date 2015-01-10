#!/bin/bash

if [ "$1" == "-h" -o -z "$1" ]
then
	echo "Script for changing default audio track of mkv to german track. Usage $0 \"film1.mkv\" \"film2.mkv\""
fi

for f in $@
do
	rm=""
	echo "$f"
	tracks="$(mediainfo --Output="Audio;%Language/String3%:%ID%:%Default%\n" "$f")"
	defid="$(echo "${track}" | grep Yes | cut -d':' -f2)"
	gerid="$(echo "${track}" | grep -E "deu|ger|Deutsch|German|Deu|Ger" | cut -d':' -f2)"
	for id in ${defid}
	do
		rm="${rm} -e track:${id} -s flag-default=0"
	done
	mkvpropedit ${rm} -e track:${gerid} -s flag-default=1 "$f"
done
