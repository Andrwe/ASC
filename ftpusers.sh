#!/bin/bash

######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: andrwe<at>andrwe<dot>org
#                  Version: 	0.0.1
#                  Description: modifies group & shell of user written to fifo
#
######################################################################

SCRIPT="$(basename $0)"
FIFOFILE="/tmp/${SCRIPT}.fifo"
FTPGROUP="ftpusers"
PREFTPGROUP="preftpusers"

function cleanup ()
{
	rm -f ${FIFOFILE}
	trap - INT TERM EXIT
}
trap 'cleanup && exit 0' INT TERM EXIT
mkfifo -m 622 ${FIFOFILE} || exit 1
exec 30<> ${FIFOFILE}

( while true
do
	while read <&30
	do
		user="${REPLY}"
		groups=( $(groups ${user} 2>/dev/null) )
		echo "$(date) ${user}"
		[[ -z "${groups[@]}" ]] && continue
		if ! grep -xFf <(printf '%s\n' ${groups[@]}) <(printf '%s\n' ${FTPGROUP[@]}) >/dev/null && grep -xFf <(printf '%s\n' ${groups[@]}) <(printf '%s\n' ${PREFTPGROUP[@]}) >/dev/null
		then
			usermod -g ${FTPGROUP} -s /bin/false ${user}
		fi
	done
done ) &
