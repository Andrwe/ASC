#!/bin/bash

URL="http://osm.pleiades.uni-wuppertal.de/openfietsmap/EU_2013/GPS/"
targetdir="/data/downloads/"
mapdir="${targetdir}maps/"

[ -e "${targetdir}" ] || mkdir -p "${targetdir}"
[ -e "${mapdir}" ] || mkdir -p "${mapdir}"

for i in $(wget "${URL}" -q -O - | sed '/<table>/,/<\/table>/ !d;s/.*href="\([^"]*\)".*/\1/g;/^OFM/ !d')
do
	wget "${URL}${i}" -O "${targetdir}/${i}"
	( tfile="${i//.zip/.img}" && tfile="${tfile,,}" && tfile="${tfile##*\/}" && unzip -qq -d "${mapdir}" "${targetdir}/${i}" garmin/gmapsupp.img && mv "${mapdir}/garmin/gmapsupp.img" "${mapdir}/garmin/${tfile}" ) &
done
