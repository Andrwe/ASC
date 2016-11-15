#!/bin/bash

######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: lord-weber-andrwe<at>andrwe<dot>org
#                  Version: 0.4
#
######################################################################

######################################################################
#                  script variables and functions
######################################################################

# Set name of the repository
REPONAME="andrwe seiichiro"
# Define pipe seperated list of packages to be skipped
#   wildcards and regex can be used
#   e.g.: BLACKLIST="aws-.*|actkbd"
BLACKLIST="ruby-.*"

# command to get aur version of a package
#  - has to return only version string
#  - is later called using "AURVERCMD pkg"
SKIP_MISS=false
[[ "${1}" == "-s" ]] && SKIP_MISS=true && shift
function AURVERCMD() {
  local resp="$(wget -O- "https://aur.archlinux.org/rpc.php?type=info&arg=${1}" -q)"
  if [[ $(echo "${resp}" | jshon -e 'resultcount' -u) -gt 0 ]]; then
    echo "$(echo "${resp}" | jshon -e "results" -e "Version" -u)"
  else
    ${SKIP_MISS} || echo "aur_missing"
  fi
}

# cleanup command for pkg db
# for pkg in $(zcat andrwe.db.tar.gz | grep -a -A1 '%NAME%' | grep -v '%NAME%' | grep -v '\-\-' | sort -u);do ls "$pkg"* &>/dev/null || repo-remove andrwe.db.tar.gz "$pkg";done

######################################################################
#
#                  No changes needed after this line.
#
######################################################################

export LANG=C
[[ -n "${@}" ]] && REPONAME="${@}"

while read repo pkg pacver state; do
  [[ ${pkg} =~ ${BLACKLIST} ]] && continue
  if ! [[ ${pkg} =~ .*-(git|svn|cvs|hg) ]]; then
    aurver="$(AURVERCMD "${pkg}" 2>/dev/null)"
    [[ -z "${aurver}" ]] && continue
    pacver_num="${pacver//[-._]/}"
    aurver_num="${aurver//[-._]/}"
    [[ ${DEBUG} -gt 0 ]] && echo "${repo} ${pkg} ${pacver} ${aurver}"
    if [[ ${pacver_num} =~ ^[0-9]+$ ]] && [[ ${aurver_num} =~ ^[0-9]+$ ]]; then
      [[ ${pacver_num##0} -lt ${aurver_num##0} ]] && echo "${repo} ${pkg} ${pacver} -> ${aurver}" && continue
      pacver_array=( ${pacver//[-._]/ } )
      aurver_array=( ${aurver//[-._]/ } )
      for ((i=0; i<${#pacver_array[@]}; i++)); do
        [[ ${pacver_array[$i]##0} -lt ${aurver_array[$i]##0} ]] && echo "${repo} ${pkg} ${pacver} -> ${aurver}" && break
      done
      continue
    fi
    [[ "${pacver}" != "${aurver}" ]] && echo "${repo} ${pkg} ${pacver} -> ${aurver}"
  fi
done <<<"$(pacman -Sl ${REPONAME})"
