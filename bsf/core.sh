#!/bin/bash
#
######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: lord-weber-andrwe <at> andrwe <dot> org
#                  Version: 0.1
#                  URL: http://andrwe.dyndns.org/doku.php/scripting/bash/bsf
#
##################
#
#                  Sumary: 
#                   Framework for bash scripting providing core
#                   function used in many scripts
#
######################################################################

######################################################################
#
#                 TODO:
#                  - implement:
#                     log
#                     debug
#                     wget (auto-nocheck)
#                     module based include
#                     dependency checking
#                     trap
#                     escaping
#                     comments
#
######################################################################

COREPATH="$(readlink -f $0)"
BSFPATH="${COREPATH%/*}"
CONFIGPATH="${BSFPATH}/bsf.config"

for module in $@
do
  source "${BSFPATH}/${module}.sh"
done
