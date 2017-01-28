#!/bin/bash

#############################################
#
#   Meta data
#
# written by:  Andreas Ulm
# created:     2017-01-28
# Description: Script to manage serial ports over
#               TCP connections using socat.
#
#############################################

#####################
#                   #
#  default config   #
#                   #
#####################

# define directory for temporary files
TMP="/tmp/virt-serial"
# define directory for log files
LOGDIR="/var/log/virt-serial"
# user allowed to access created com port
COMUSER="root"
# base path for com port
DEVPATH="/dev/virt-serial"

# define colors for output
RED='\e[1;31m'
GREEN='\e[1;32m'
DEF='\e[0m'


#####################
#                   #
#     functions     #
#                   #
#####################

# define usage function
#   call of this function results in script exit with given code
function usage() {
    echo "$0 [-c config] (-a target|-d target|-h|-l target)"
    echo
    echo " This script must be run as root"
    echo
    echo "  -a target = activate connection to target"
    echo "  -c config = use specified configuration file"
    echo "  -d target = deactivate connection to target"
    echo "  -l        = list active connections"
    echo
    echo "    target = ip-address[:port]"
    echo
    echo "  config may define the following parameters:"
    echo "    TMP     = directory for temporary files"
    echo "    LOGDIR  = directory for log files"
    echo "    COMUSER = user allowed to access created com port"
    echo "    DEVPATH = base path for com port"
    echo
    exit "${1}"
}

# check necessary environment
function checkEnv() {
    # check for root permission
    if [ $EUID -ne 0 ]; then
        echo "${RED}This function of the script has to be run as root.${DEF}" >&2
        error=1
    fi
    # check for socat command
    if ! which socat &>/dev/null; then
        echo "${RED}Please install 'socat'-command${DEF} (e.g. apt-get install socat, pacman -S socat)" >&2
        error=1
    fi

    echo
    [[ ${error} -eq 1 ]] && usage 5
}

# check if connection to given ip-address and port already exists
#   if it exists load its configration & return 0
#   if it does not exist return 1
function checkCon() {
    local ip="${1}"
    local port="${2}"
    local pidfile="${TMP}/${ip}_${port}.pid"
    local conffile="${TMP}/${ip}_${port}.conf"

    # exit script if port is missing
    if [[ -z "${port}" ]]; then
        echo -e "${RED}port is missing${DEF}"
        echo
        usage 7
    fi
    if ! [[ "${port}" =~ [0-9][0-9]* ]]; then
        echo -e "${RED}port is invalid${DEF}"
        echo
        usage 7
    else
        if [[ ${port} < 1 || ${port} > 65534 ]]; then
            echo -e "${RED}port is invalid${DEF}"
            echo
            usage 7
        fi
    fi

    # create tmp directory if missing
    [[ -d "${TMP}" ]] || mkdir -p "${TMP}"

    # check pidfile for existing process
    if [[ -f "${pidfile}" ]]; then
        if pgrep -F "${pidfile}" >/dev/null; then
            export PID="$(<"${pidfile}")"
            [[ -e "${conffile}" ]] && source "${conffile}"
            return 0
        else
            cleanup "${ip}" "${port}"
            return 1
        fi
    else
        return 1
    fi
}

# delete temporary files
function cleanup() {
    local ip="${1}"
    local port="${2}"
    local pidfile="${TMP}/${ip}_${port}.pid"
    local conffile="${TMP}/${ip}_${port}.conf"
    local logfile="${LOGDIR}/${ip}_${port}.log"

    rm -f "${conffile}" "${pidfile}"
    echo "$(date) run cleanup for target ${ip}:${port} initiated by ${SUDO_USER}" >> "${logfile}"
}

# activate connection for given target
function activate() {
    ip="${1}"
    port="${2}"
    if checkCon "${ip}" "${port}"; then
        echo -e "${RED}connection for ${ip}:${port} already exists:${DEF}"
        echo "  PID:        ${PID}"
        echo "  COMPATH:    ${COMPATH}"
        echo "  started at: ${STARTED}"
    else
        pidfile="${TMP}/${ip}_${port}.pid"
        conffile="${TMP}/${ip}_${port}.conf"
        logfile="${LOGDIR}/${ip}_${port}.log"

        # get amount of running connections
        count="$(ls /dev/virt-serial* 2>/dev/null | wc -l)"
        let "count++"
        # get available connection path
        while [[ -e "${DEVPATH}${count}" ]]; do
            let "count++"
        done

        # start com port connection in background
        socat -d -d -d pty,link="${DEVPATH}${count}",rawer,user="${COMUSER}",wait-slave tcp:"${ip}":"${port}" &>> "${logfile}" &
        echo "$!" > "${pidfile}"

        if checkCon "${ip}" "${port}"; then
            date="$(date)"
            echo "# Started connection at $(date)" > "${conffile}"
            echo "STARTED='${date}'" >> "${conffile}"
            echo "COMPATH='${DEVPATH}${count}'" >> "${conffile}"

            echo -e "${GREEN}Successfully started connection.${DEF}"
            echo "  PID:     ${PID}"
            echo "  COMPATH: ${DEVPATH}${count}"
            echo "  started: ${date}"
            echo "  logfile: ${logfile}"
        else
            echo -e "${RED}Failed to start connection.${DEF}"
            echo "See logfile ${logfile}"
        fi
    fi
}

# deactivate given connection
function deactivate() {
    ip="${1}"
    port="${2}"
    if checkCon "${ip}" "${port}"; then
        if kill "${PID}" &>/dev/null; then
            cleanup "${ip}" "${port}"
            echo -e "${GREEN}Successfully deactivated connection for target '${ip}:${port}' (${PID})${DEF}"
        else
            echo -e "${RED}Failed to deactivate connection for target '${ip}:${port}'${DEF}"
        fi
    else
        echo "Connection for target '${ip}:${port}' not found"
    fi
}

# find and list all running connections
function list() {
    ip="${1}"
    port="${2}"
    echo "The following connections are currently established:"
    if ls "${TMP}"/*.pid &>/dev/null; then
        for pidfile in "${TMP}"/*.pid; do
            file="${pidfile##*/}"
            file="${file%%.pid}"
            read ip port <<<"${file//_/ }"
            if checkCon "${ip}" "${port}"; then
                echo "  TARGET:  ${ip}:${port}"
                echo "    PID:     ${PID}"
                echo "    COMPATH: ${COMPATH}"
                echo "    started: ${STARTED}"
                echo "    logfile: ${LOGDIR}/${ip}_${port}.log"
            fi
        done
    else
        echo "  No active connections"
    fi
}


#####################
#                   #
#    main script    #
#                   #
#####################

# read all commandline arguments & define action to be run
while getopts ':a:c:d:hl' opt
do
    case "${opt}" in
        "a")
            read ip port <<<"${OPTARG//:/ }"
            ACTION="activate"
        ;;
        "c")
            config="${OPTARG}"
        ;;
        "d")
            read ip port <<<"${OPTARG//:/ }"
            ACTION="deactivate"
        ;;
        "h")
            usage 0
        ;;
        "l")
            ACTION="list"
        ;;
        '?')
            echo -e "${RED}unknown option -${OPTARG}${DEF}"
            echo
            usage 2
        ;;
        ':')
            echo -e "${RED}-${OPTARG} requires an argument${DEF}"
            echo
            usage 3
        ;;
        *)
            echo -e "${RED}error while parsing given options${DEF}"
            echo
            usage 1
        ;;
    esac
done

[[ -z "${ACTION}" ]] && usage 0

checkEnv

# allow overwrite of all configuration parameters defined above
[[ -n "${config}" && -e "${config}" ]] && source "${config}"

# restrict access for all created files & directories to root
umask 0027

# create log directory if missing
[[ -d "${LOGDIR}" ]] || mkdir -p "${LOGDIR}"

case "${ACTION}" in
    "activate")
        activate "${ip}" "${port}"
    ;;
    "deactivate")
        deactivate "${ip}" "${port}"
    ;;
    "list")
        list
    ;;
esac
