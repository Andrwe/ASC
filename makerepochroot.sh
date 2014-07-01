#!/bin/bash

confdir="$(dirname $(readlink -f $0))/repo-conf/"
mirrorurl="http://www.archlinux.org/mirrorlist/?country=DE&protocol=http&ip_version=4&use_mirror_status=on"

if [ ${#@} -ne 2 ]
then
	echo "Usage: $0 <arch[,arch]> <repo-dir>
Config directory: ${confdir}" >&2
fi

function mkchroot()
{
	opt=""
	grep -E "^\s*CacheDir" "${confdir}/pacman-${1}.conf" >/dev/null 2>&1 && opt="-c $(grep -E "^\s*CacheDir" "${confdir}/pacman-${1}.conf" | sed 's/[^=]*=\s*\([^ ]*\)\s*$/\1/g')"
	sudo mkarchroot -C "${confdir}/pacman-${1}.conf" -M "${confdir}/makepkg-${1}.conf" "${opt}" "${2}" base base-devel sudo || return $?
}

for arch in ${1//,/ }
do
	[ -e "${confdir}/pacman-${arch}.conf" ] || { echo "pacman.conf for ${arch} doesn't exist." >&2 && exit 1 ; }
	[ -e "${confdir}/makepkg-${arch}.conf" ] || { echo "makepkg.conf for ${arch} doesn't exist." >&2 && exit 1 ; }
	[ -d "${2}/${arch}" ] || { echo "repo directory ${2}/${arch} for ${arch} doesn't exist. Creating." >&2 && mkdir -p "${2}/${arch}" ; }
	echo
	echo
	echo "Creating chroot for ${arch}"
	echo
	sudo mv /etc/pacman.d/mirrorlist{,_chrootbkp} && wget -q -O - "${mirrorurl}" | sudo bash -c "sed 's/^#//g' > /etc/pacman.d/mirrorlist"
	mkchroot "${arch}" "${2}/${arch}/root" || { echo "An error occured while creating chroot for ${arch}. (return-code of mkarchroot: $?)" >&2 && exit 1 ; }
	sudo mv /etc/pacman.d/mirrorlist{_chrootbkp,}
done
