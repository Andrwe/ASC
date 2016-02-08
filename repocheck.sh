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
function AURVERCMD() {
  local resp="$(wget -O- "https://aur.archlinux.org/rpc.php?type=info&arg=${1}" -q)"
  if [[ $(echo "${resp}" | jshon -e 'resultcount' -u) -gt 0 ]]; then
    echo "$(echo "${resp}" | jshon -e "results" -e "Version" -u)"
  else
    echo "aur_missing"
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

while read repo pkg pacver state; do
  [[ ${pkg} =~ ${BLACKLIST} ]] && continue
  if ! [[ ${pkg} =~ .*-(git|svn|cvs|hg) ]]; then
    aurver="$(AURVERCMD "${pkg}" 2>/dev/null)"
    if [[ -z "${aurver}" ]]; then
      [[ DEBUG -gt 0 ]] && echo "no AUR version for ${pkg}"
      continue
    fi
    pacver_num="${pacver//[-._]/}"
    aurver_num="${aurver//[-._]/}"
    if [[ ${pacver_num} =~ ^[0-9]+$ ]] && [[ ${aurver_num} =~ ^[0-9]+$ ]]; then
      [[ ${pacver_num##0} -lt ${aurver_num##0} ]] && echo "${repo} ${pkg} ${pacver} -> ${aurver}"
      continue
    fi
    [[ "${pacver}" != "${aurver}" ]] && echo "${repo} ${pkg} ${pacver} -> ${aurver}"
  fi
done <<<"$(pacman -Sl ${REPONAME})"
