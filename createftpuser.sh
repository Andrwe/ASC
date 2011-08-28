#!/bin/bash

######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: andrwe<at>andrwe<dot>org
#                  Version: 	0.0.1
#                  Description: creates users/dirs for sftp
#
######################################################################

[[ -z "$@" ]] && echo "No user given." && exit 1
[[ ${UID} -ne 0 ]] && echo "Must be root." && exit 1

user="${1}"
ftpdir="/data/ftp/${user}"
useradd -s /usr/local/bin/ftpFirstLogin.sh -d "${ftpdir}" -g preftpusers "${user}" || exit 1
passwd "${user}" || exit 1

install -o root -g root -m 755 -dD "${ftpdir}"
install -o "${user}" -g ftpusers -m 500 -dD "${ftpdir}"/{films,music,public}
install -o "${user}" -g ftpusers -m 700 -dD "${ftpdir}"/upload
