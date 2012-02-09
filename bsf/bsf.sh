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
#                     trap (trapstart, trapstop, Parameter: "command","signals")
#                     escaping
#                     comments
#                     usage (-h, -?)
#                     help-module (longhelp, shorthelp)
#                     parameter function (:-seperated list of parameters for module eg. log:syslog:serveraddress:port; - & :: = skip option)
#                     PID-management
#                  - rules:
#                     Knowledge (available functions, parameters, ...) about module has only the module itself
#
######################################################################

COREPATH="$(readlink -f $0)"
BSFPATH="${COREPATH%/*}"
CONFIGPATH="${BSFPATH}/bsf.config"

while getopts ":h:?:" opt
do
  case "${opt}" in
    "h")
      if [ -z "${OPTARGS}" ]
      then
        for module in "${BSFPATH}/"*
        do
          echo ${module}
        done
      else
      fi
    ;;
  esac
done


for module in $@
do
  source "${BSFPATH}/${module}.sh"
done
