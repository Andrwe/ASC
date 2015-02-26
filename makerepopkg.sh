#!/bin/bash

######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: andrwe<at>andrwe<dot>org
#                  Version: 	1.0.0
#
######################################################################

######################################################################
#
#                  script variables and functions
#
######################################################################

# Configuration
config='
PNAME=default
PARCH=x86_64
PDBG=0
PTMPDIR=/tmp
PUSECHROOT=0
PCHROOT=-
PREPODIR=-
PREPONAME=-
PSYMLINKANY=-
PKGBUILD=PKGBUILD
'

######################################################################
#
#                  TODO
# version check for in-chroot builddepends
# parallel
# further dependency functionality
# getDepends()
# buildDepend()
# copy package of any packages when not symlinking
#
######################################################################


######################################################################
#
#                  No changes needed after this line.
#
######################################################################

PNAMECOLOR_PRE="\e[0;31m"
PNAMECOLOR_POS="\e[0m"
DEPENDS=( sed grep bash wget )

######################################################################
#
#                  Helper functions
#
######################################################################

# Check for dependencies of this script
for dep in ${DEPENDS[@]}
do
	if ! which ${dep} >/dev/null 2>&1
	then
		echo "One of the following Dependencies is missing: ${dep}. Exit"
		exit 1
	fi
done

function debug()
{
	local status=$?
	[ ${PDBG} -ge $2 ] && echo -e "$1" >&2
	return ${status}
}

function cleanup()
{
	debug "Removing temporary files ... " 0
	rm ${rmOpts} -rf ${LOCKFILE}
	debug "temporary files removed." 0
}

function usage()
{
	echo "
Usage: $0 [<general option>] <command>
  Commands:
    -P -[s|w|d|l|h] : Profile modifications (see -Ph for more information)
    -B              : Build operations (see -Bh for more information)
    -D -[l]         : Dependecy operations (see -Dh for more information)
  General options:
    -h              : this help
    -v [1|2]        : verbose output
    -q              : quiet	
    -c <directory>  : set a config directory (default: ${CONFIGDIR})
"
}

function usageP()
{
	echo "
Usage: $0 -P
  -s <profile>[,<profile>,...] : show configuration of given profiles
                   (If profile is '--all' all profiles will be shown)

  -w                           : create/modify profile
    each value can be set using these parameters:
      -a <architecture>        : set architecture
      -c <chroot-dir>          : set chroot directory
      -d <lvl>                 : set debug level (-1,0,1,2)
      -p <profile-name>        : set name of profile
      -t <tmp-dir>             : set directory for temporary files
      -r <repo-dir>            : set directory for repository files
      -R <repo-name>           : set repository name
      -s <0|1>                 : use symlinks for packages with architecture any
      -u <0|1>                 : use chroot environment (0 = -c is omitted)

    Examples:
      create profile 'test':
        -Pw -p test -a i686 -c /chroot -d 0 -t /tmp

  -d <profile>[,<profile>,...] : delete given profiles
  -l                           : list existing profiles
  -h                           : this help

  Profile syntax:
    # config-${TMPNAME}
    PARCH=<architecture>
    PCHROOT=<chroot-directory>
    PREPODIR=<chroot-directory>
    PUSECHROOT=<0|1>
    PTMPDIR=<directory-for-temporary-files>
    PREPODIR=<directory-for-repository-files>
    PREPONAME=<repository-name>
    PSYMLINKANY=<0|1>
    PDBG=<debug-level>
"
}

function usageD()
{
	echo "
Usage: $0 -D
  -p <profile>[,<profile>,...] : build package for given profiles
  -P <PKGBUILD>                : use given PKGBUILD for build
  -l                           : list dependencies with status on the system
  -h                           : this help
"
}

function usageB()
{
	echo "
Usage: $0 -B
  -p <profile>[,<profile>,...] : build package for given profiles
  -P <PKGBUILD>                : use given PKGBUILD for build
  -c                           : do not copy package into repository directory after build
  -u                           : skip updating chroot
  -h                           : this help
"
}
######################################################################
#
#                  Profile functions
#
######################################################################

# Arguments: profile-name
# Return-code:
#   0: is valid profile
#   1: isn't valid profile
function checkProfile()
{
	local pname status
	pname="${1}"
	status=0
	grep "config-${TMPNAME}" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PARCH" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PUSECHROOT" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PCHROOT" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PTMPDIR" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PREPODIR" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PREPONAME" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PSYMLINKANY" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PDBG" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	grep "PKGBUILD" "${CONFIGDIR}/${pname}" >/dev/null || status=1
	return ${status}
}

# Arguments: profile
# Return-code:
#   1 - not shown, either profile doesn't exist or not valid
function showProfile()
{
	debug "showProfile() $@" 2
	local pname=${1}
	[ ! -r "${CONFIGDIR}/${pname}" ] && echo -e "The profile ${PNAMECOLOR_PRE}${pname}${PNAMECOLOR_POS} doesn't exists." && return 1
	checkProfile "${pname}" || ! echo -e "The profile ${PNAMECOLOR_PRE}${pname}${PNAMECOLOR_POS} is not a valid profile. Skip." || return 1 
	echo -e "\nProfile ${PNAMECOLOR_PRE}${pname}${PNAMECOLOR_POS} has this configuration:\n"
	cat "${CONFIGDIR}/${pname}" | grep -v "^#"
	echo
}

# Arguments: pname parch pchroot pusechroot ptmpdir pdbg prepodir preponame psymlinkany
function writeProfile()
{
	local pname parch pchroot pusechroot ptmpdir pdbg prepodir preponame psymlinkany replace
	pname="${1}"
	parch="${2}"
	pchroot="${3}"
	pusechroot="${4}"
	ptmpdir="${5}"
	pdbg="${6}"
	prepodir="${7}"
	preponame="${8}"
	psymlinkany="${9}"
	[ ! -d "${CONFIGDIR}" ] && mkdir -p "${CONFIGDIR}"
	[ "-" == "${pname}" -o "-" == "${parch}" -o "-" == "${pchroot}" -o "-" == "${pusechroot}" -o "-" == "${ptmpdir}" -o "-" == "${pdbg}" -o "-" == "${prepodir}" -o "-" == "${psymlinkany}" ] && echo -e "\nWelcome to the configuration assistent.\n\nThe given values are either default or of the existing profile and are changable.\n\n"
	[ "-" == "${pname}" ] && read -ep "Profile-Name: " -i ${PNAME} pname
	[ "-" == "${parch}" ] && read -ep "Architecture: " -i ${PARCH} parch
	[ "-" == "${pusechroot}" ] && read -ep "Use Chroot  : " -i ${PUSECHROOT} pusechroot
	[ ${pusechroot} -eq 1 -a "-" == "${pchroot}" ] && read -ep "Chroot-Dir  : " -i ${PCHROOT} pchroot
	[ "-" == "${ptmpdir}" ] && read -ep "TMP-Dir     : " -i ${PTMPDIR} ptmpdir
	[ "-" == "${pdbg}" ] && read -ep "Debug-level : " -i ${PDBG} pdbg
	[ "-" == "${prepodir}" ] && read -ep "Repo-Dir    : " -i ${PREPODIR} prepodir
	[ "-" == "${psymlinkany}" ] && read -ep "Use Symlink  : " -i ${PSYMLINKANY} psymlinkany
	[ "-" == "${preponame}" ] && read -ep "Repo-Name   : " -i ${PREPONAME} preponame

	[ -r "${CONFIGDIR}/${pname}" ] && read -p "Do you want to replace the existing profile - ${pname} - ?(Y/n)" replace && [ "${replace}" == "n" -o "${replace}" == "N" ] && exit
	echo -e "\nThis is the configuration that would be build.\n\nPARCH='${parch}'\nPCHROOT='${pchroot}'\nPUSECHROOT='${pusechroot}'\nPTMPDIR='${ptmpdir}'\nPDBG='${pdbg}'\nPREPODIR='${prepodir}'\nPREPONAME='${preponame}'\nPSYMLINKANY='${psymlinkany}'\nPPKGBUILD='PKGBUILD'"
	read -p "Do you want this profile to be saved?(Y/n)" replace && [ "${replace}" == "n" -o "${replace}" == "N" ] && exit
	echo -e "# config-${TMPNAME}\nPARCH='${parch}'\nPCHROOT='${pchroot}'\nPUSECHROOT='${pusechroot}'\nPTMPDIR='${ptmpdir}'\nPDBG='${pdbg}'\nPREPODIR='${prepodir}'\nPREPONAME='${preponame}'\nPSYMLINKANY='${psymlinkany}'\nPPKGBUILD='PKGBUILD'" > "${CONFIGDIR}/${pname}"
}

# Argument: profile-name
function loadProfile()
{
	local pname=${1}
	[ -r "${CONFIGDIR}/${pname}" ] && checkProfile "${pname}" && source "${CONFIGDIR}/${pname}" >/dev/null 2>&1 && debug "Config ${PNAMECOLOR_PRE}${pname}${PNAMECOLOR_POS} loaded." 0 && return
	debug "Couldn't load config ${PNAMECOLOR_PRE}${CONFIGDIR}/${pname}${PNAMECOLOR_POS}.\nIt either doesn't exist or is invalid, check using -Pl (only valid profiles are shown).\nExit" -10 && exit 1
}

# Argument: profile-name
function removeProfile()
{
	local pname=${1}
	[ -w "${CONFIGDIR}/${pname}" ] && rm ${rmopts} "${CONFIGDIR}/${pname}" && echo -e "Profile ${PNAMECOLOR_PRE}${pname}${PNAMECOLOR_POS} removed successfully." && return
	echo -e "${PNAMECOLOR_PRE}${CONFIGDIR}/${pname}${PNAMECOLOR_POS} is not writeable. Can't remove this profile."
}

# Arguments: (bool)validcheck
# Return   : list of profiles
function getProfiles()
{
	debug "getProfiles() $@" 2
	local file files profiles validcheck
	validcheck=${1}
	[ ! -d "${CONFIGDIR}" ] && return 1
	files=`grep -lsm 1 "config-${TMPNAME}" "${CONFIGDIR}"/*`
	if ! ${validcheck}
	then 
		debug "non valid" 3
		for file in ${files}
		do
			debug "file: ${file}" 3
			checkProfile "${file/*\//}" || profiles+="${file/*\//}\n"
		done
	else
		debug "valid" 3
		for file in ${files}
		do
			debug "file: ${file}" 3
			checkProfile "${file/*\//}" && profiles+="${file/*\//}\n"
		done
	fi
	debug "Profiles: ${profiles}" 3
	echo -ne "${profiles:0:${#profiles}-2}"
}

# Arguments: none
function listProfiles()
{
	debug "listProfiles()" 2
	local profiles
	echo -e "\nExisting valid profile(s):\n"
	profiles=`getProfiles true`
	[ -z "${profiles}" ] && echo "None"
	[ -n "${profiles}" ] && echo "${profiles}"
	echo
	unset profiles
	echo -e "\nExisting non-valid profile(s):\n"
	profiles=`getProfiles false`
	[ -z "${profiles}" ] && echo "None"
	[ -n "${profiles}" ] && echo "${profiles}"
	echo
}


######################################################################
#
#                  Dependency functions
#
######################################################################

# Arguments: dependency
# Return-code:
#   5: installed
#   6: in repository
#   7: in AUR
function checkDepend()
{
	local dep="${1}"
	debug "use chroot: ${PUSECHROOT}\ncheckDepends() ${dep}" 2
	dep="${dep%>*}"
	dep="${dep%<*}"
	if [ ${PUSECHROOT} -eq 0 ]
	then
		pacman -T "${dep}" >/dev/null && debug "used: pacman -T ${dep}\nError-code: $?" 2 && return 5
		debug "used: pacman -T ${dep}\nError-code: $?" 2 
		pacman -Si "${dep}" >/dev/null 2>&1 && debug "used: pacman -Si ${dep}\nError-code: $?" 2 && return 6
		debug "used: pacman -Si ${dep}\nError-code: $?" 2 
		wget -q -t 3 --spider --no-check-certificate "https://aur.archlinux.org/packages/${dep}/${dep}.tar.gz" && debug "used: wget https://aur.archlinux.org/packages/${dep}/${dep}.tar.gz\nError-code: $?" 2 && return 7
		debug "used: wget https://aur.archlinux.org/packages/${dep}/${dep}.tar.gz\nError-code: $?" 2
	else
		sudo arch-nspawn "${PCHROOT}"/root bash -c "pacman -T ${dep} &>/dev/null" && debug "used: pacman -T ${dep}\nError-code: $?" 2 && return 5
		debug "used: pacman -T ${dep}\nError-code: $?" 2 
		sudo arch-nspawn "${PCHROOT}"/root bash -c "pacman -Si ${dep} &>/dev/null" && debug "used: pacman -Si ${dep}\nError-code: $?" 2 && return 6
		debug "used: pacman -Si ${dep}\nError-code: $?" 2 
		wget -q -t 3 --spider --no-check-certificate "https://aur.archlinux.org/packages/${dep}/${dep}.tar.gz" && debug "used: wget https://aur.archlinux.org/packages/${dep}/${dep}.tar.gz\nError-code: $?" 2 && return 7
		debug "used: wget https://aur.archlinux.org/packages/${dep}/${dep}.tar.gz\nError-code: $?" 2
	fi
}

# Arguments: none
# Return-code:
#   0: all needed dependencies are installed
#   1: dependencies are missing but all in repository => can continue building
#   2: dependencies are missing and some only in AUR  => can't continue building
#   3: dependency status unknown                      => can't continue unless wanted
function listDepends()
{
	local status statusInstalled dep
	statusInstalled=0
	echo -e "\nDependencies:\n"
	for dep in ${depends[@]} ${makedepends[@]}
	do
		checkDepend "${dep}" >/dev/null 2>&1
		debug "Status: $?" 2
		case $? in
			5)
				status="installed"
				;;
			6)
				status="in repository"
				[ ${statusInstalled} -lt 1 ] && statusInstalled=1
				;;
			7)
				status="in AUR"
				[ ${statusInstalled} -lt 2 ] && statusInstalled=2
				;;
			*)
				status="unknown"
				[ ${statusInstalled} -lt 3 ] && statusInstalled=3
		esac
		debug "  ${dep} [${status}]" -10
	done
	echo 
	debug "status of packages: ${statusInstalled}" 2
	return ${statusInstalled}
}

function buildDepend()
{
	echo Not implemented yet
}

function getDepends()
{
	echo Not implemented yet
}


######################################################################
#
#                  Build functions
#
######################################################################

# Arguments:
# Return-codes:
#   0: PKGBUILD valid
#   1: variable $startdir used
#   2: variable $install is array
function checkPKGBIULD()
{
	local status=0
	grep startdir ${PKGBUILD} >/dev/null 2>&1 && debug "The PKGBUILD uses the old variable startdir which isn't supported by this script.\nPlease replace \$startdir/src with \$srcdir, \$startdir/pkg with \$pkgdir and inform the package maintainer about it. Exit\n" -10 && status=1
	grep "install=(" ${PKGBUILD} >/dev/null 2>&1 && debug "The PKGBUILD uses the install-variable as array which isn't supported by this script.\nPlease remove () from the value and inform the package maintainer about it. Exit\n" -10 && status=2
	return ${status}
}

# Arguments: 
function copyPkg()
{
	local pkgfile="${pkgname}-${pkgver}-${pkgrel}-${PARCH}.pkg.tar.[gx]z"
	if [ ! -d "${PREPODIR}" ]
	then
		local choice
		debug "The repository directory ${PREPODIR} doens't exist." -10
		read -p "Should it be created? (y/N)" choice
		if [ "${choice}" == "y" -o "${choice}" == "Y" ]
		then
			mkdir -p "${PREPODIR}"
		else
			debug "Skip copy process." -10
			return 1
		fi
	fi
	if [ "${PARCH}" == "any" -a ${PSYMLINKANY} -eq 1 ]
	then
		debug "copyPkg PNAME: ${PNAME}" 3
		if [ -n "${srcrepodir}" ]
		then
			if [ -h "${PREPODIR}"/${pkgname}-${pkgver}-${pkgrel}-any.pkg.tar.[gx]z ]
			then
				debug "Package and a symlink already exists (Package in: ${srcrepodir}). Exit" 0
			else
				debug "Package already exists in ${srcrepodir}. Creating a symlink." 0
				ln -s "${srcrepodir}"${pkgname}-${pkgver}-${pkgrel}-any.pkg.tar.[gx]z "${PREPODIR}"/${pkgname}-${pkgver}-${pkgrel}-any.pkg.tar.xz
				debug "Symlink created." 0
			fi
		fi
	else
		[ ! -f ${pkgfile} ] && debug "Package-file ${pkgfile} doens't exist. Exit" 0 && exit 1
		cp ${pkgfile} "${PREPODIR}"
	fi
	repo-add "${PREPODIR}"/"${PREPONAME}".db.tar.gz "${PREPODIR}"/${pkgfile}
}

# Arguments: profile-name
function makePkg()
{
	local pname=${1}
	checkPKGBIULD || exit 1
	loadProfile ${pname} || exit 1
	[ "${PARCH}" == "i686" ] && plinux=linux32
	[ "${PARCH}" == "x86_64" ] && plinux=linux64
	
	debug "Changing into PKGBUILD-directory ($(dirname ${PKGBUILD}))." 0
	rundir="$PWD"
	runpkgbuild="${PKGBUILD}"
	cd "$(dirname "${PKGBUILD}")"
	PKGBUILD="$(basename "${PKGBUILD}")"
	source ${PKGBUILD}
	if [[ ${arch[@]} =~ any ]] 
	then
		if [ ${PSYMLINKANY} -eq 1 ]
		then
			debug "SYMLINKANY is enabled thus checking for package in other profiles." 0
			debug "makePkg PNAME: ${PNAME}" 3
			local srcrepodir
			for profile in `getProfiles true | tr '\n' ' '`
			do
				loadProfile ${profile}
				if [ -f "${PREPODIR}"/${pkgname}-${pkgver}-${pkgrel}-any.pkg.tar.[gx]z  ]
				then
					srcrepodir="${PREPODIR}"
				fi
			done
			loadProfile ${pname}
		fi
		PARCH="any"
	fi
	if [ -z "${srcrepodir}" ]
	then
		debug "Checking dependencies ..." 0
		listDepends
		case $? in
			2)
				debug "Some dependencies are only available through AUR, add them to a repository or install them first. Skip" -10
				return 1
				;;
			3)
				debug "Some dependencies have unknown status. Skip" -10
				return 1
				;;
		esac
		debug "Checking for old builds and delete them." 0
		for file in ${pkgname}-*-*-${PARCH}.pkg.tar.[xg]z
		do
			debug "${file}" 0
			rm -f "${file}"
		done
		if [ ${PUSECHROOT} -eq 0 ]
		then
			debug "Build package using non-chroot-command makepkg." 0
			if [ ${PDBG} -eq -1 ]
			then
				makepkg -cs >/dev/null
			else
				makepkg -cs
			fi
		else
			debug "Build package using chroot-command makechrootpkg." 0
			debug "makePkg() ${PCHROOT} ${PARCH} ${pname}" 1
			if [ ${PDBG} -eq -1 ]
			then
				${notupdate} || sudo ${plinux} makechrootpkg -u -c -r "${PCHROOT}" >/dev/null
				${notupdate} && sudo ${plinux} makechrootpkg -c -r "${PCHROOT}" >/dev/null
			else
				${notupdate} || sudo ${plinux} makechrootpkg -u -c -r "${PCHROOT}"
				${notupdate} && sudo ${plinux} makechrootpkg -c -r "${PCHROOT}"
			fi
		fi
		debug "Build done" 0
	fi
	${notcopy} || copyPkg
	PKGBUILD="${runpkgbuild}"
	cd "${rundir}" >/dev/null
}



######################################################################
#
#                  Main functions
#
######################################################################

trap "cleanup" INT TERM EXIT

mode=""
action=""
notcopy=false
notupdate=false

export ${config}

# loop for options
while getopts ":hqv:c:Ps:wd:lBDb:p:R:" opt
do
	case "${opt}" in 
		"v")
			readonly PDBG="${OPTARG}"
			;;
		"q")
			readonly PDBG=-1
			;;
		"c")
			[ ! -d "${OPTARG}" ] && echo "Given config directory ${OPTARG} does not exist. Using ${CONFIGDIR} instead." && continue
			CONFIGDIR=${OPTARG}
			;;
		"P")
			mode="P"
			debug "Mode set to ${mode}" 2
			while getopts ":ws:d:lh" opt
			do
				case "${opt}" in
					"s")
						[ ${PDBG} -eq 0 ] && PDBG=-1
						PNAME="${OPTARG}"
						[[ ${PNAME} =~ "--all" ]] && PNAME=`getProfiles true | tr '\n' ','`
						debug "Ps-option PNAME: ${PNAME}" 3
						[ -z ${PNAME} ] && debug "No valid profiles found." -10 && exit 1
						for pname in ${PNAME//,/ }
						do
							action+="showProfile ${pname};"
						done
						;;
					"w")
						debug "Write mode started" 2
						pname="-"
						parch="-"
						pchroot="-"
						pusechroot="-"
						ptmpdir="-"
						pdbg="-"
						prepodir="-"
						preponame="-"
						while getopts ":a:c:d:t:p:u:r:R:s:" wopt
						do
							case ${wopt} in
								"a")
									parch="${OPTARG}"
									;;
								"c")
									pchroot="${OPTARG}"
									;;
								"d")
									pdbg="${OPTARG}"
									;;
								"p")
									pname="${OPTARG}"
									;;
								"t")
									ptmpdir="${OPTARG}"
									;;
								"u")
									pusechroot="${OPTARG}"
									;;
								"r")
									prepodir="${OPTARG}"
									;;
								"R")
									preponame="${OPTARG}"
									;;
								"s")
									psymlinkany="${OPTARG}"
									;;
								":")
									echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
									usage${mode}
									[ ${PDBG} -eq 0 ] && PDBG=-1
									exit 1
									;;
							esac
							debug "${pname} ${parch} ${pchroot} ${pusechroot} ${ptmpdir} ${pdbg} ${prepodir} ${preponame} ${psymlinkany}" 2
						done
						action="writeProfile ${pname} ${parch} ${pchroot} ${pusechroot} ${ptmpdir} ${pdbg} ${prepodir} ${preponame} ${psymlinkany}"
						;;
					"d")
						ifs=${IFS}
						IFS=","
						for profile in ${OPTARG}
						do
							IFS=${ifs}
							[ -n "${action}" ] && action="${action};removeProfile ${profile}"
							[ -z "${action}" ] && action="removeProfile ${profile}"
							IFS=","
						done
						IFS=${ifs}
						;;
					"l")
						[ ${PDBG} -eq 0 ] && PDBG=-1
						action="listProfiles ${OPTARG}"
						;;
					"h")
						usageP
						[ ${PDBG} -eq 0 ] && PDBG=-1
						exit 0
						;;
					":")
						echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
						usage${mode}
						[ ${PDBG} -eq 0 ] && PDBG=-1
						exit 1
						;;
				esac
			done
			;;
		"B")
			mode="B"
			debug "Mode set to ${mode}" 2
			while getopts ":p:hcP:" bopt
			do
				case ${bopt} in
					"p")
						PNAME=${OPTARG}
						;;
					"P")
						[ ! -r "${OPTARG}" ] && debug "Can't read given PKGBUILD (${OPTARG}).\nPlease check permissions.\nExit" 0 && exit 1
						export PKGBUILD="${OPTARG}"
						;;
					"c")
						notcopy=true
						;;
					"u")
						notupdate=true
						;;
					":")
						echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
						usage${mode}
						[ ${PDBG} -eq 0 ] && PDBG=-1
						exit 1
						;;
					"h")
						usage${mode}
						[ ${PDBG} -eq 0 ] && PDBG=-1
						exit 1
						;;
				esac
			done
			[[ ${PNAME} =~ "--all" ]] && PNAME=`getProfiles true | tr '\n' ','`
			[ -z ${PNAME} ] && debug "No valid profiles found." -10 && exit 1
			for pname in ${PNAME//,/ }
			do
				debug "${pname}" 3
				[ ! -r "${CONFIGDIR}/${OPTARG}" ] && debug "Can't read given profile (${OPTARG}).\nPlease check permissions.\nSkip" 0 && continue
				action+="makePkg ${pname};"
			done
			debug "${action}" 3
			;;
		"D")
			mode="D"
			debug "Mode set to ${mode}" 2
			while getopts ":P:p:lh" dopt
			do
				case "${dopt}" in
					"p")
						[ ${PDBG} -eq 0 ] && PDBG=-1
						PNAME="${OPTARG}"
						[[ ${PNAME} =~ "--all" ]] && PNAME=`getProfiles true | tr '\n' ','`
						debug "Ps-option PNAME: ${PNAME}" 3
						[ -z ${PNAME} ] && debug "No valid profiles found." -10 && exit 1
						;;
					"P")
						[ ! -r "${OPTARG}" ] && debug "Can't read given PKGBUILD (${OPTARG}).\nPlease check permissions.\nExit" 0 && exit 1
						export PKGBUILD="${OPTARG}"
						;;
					"l")
						act="list"
						;;
					"h"|*)
						usage${mode}
						[ ${PDBG} -eq 0 ] && PDBG=-1
						exit 1
						;;
					":")
						echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
						usage${mode}
						[ ${PDBG} -eq 0 ] && PDBG=-1
						exit 1
						;;
				esac
			done
			case "${act}" in
				"list")
					if [ ${PNAME} == "default" -o -z ${PNAME} ]
					then
						action="listDepends;"
					else
						for pname in ${PNAME//,/ }
						do
							action+="loadProfile $pname && listDepends;"
						done
					fi
				;;
			esac
			source ${PKGBUILD}
			;;
		":")
			echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
			usage${mode}
			[ ${PDBG} -eq 0 ] && PDBG=-1
			exit 1
			;;
		"h"|*)
			usage${mode}
			[ ${PDBG} -eq 0 ] && PDBG=-1
			exit 0
			;;
	esac
done

[ -z "${action}" ] && usage${mode} && [ ${PDBG} -eq 0 ] && PDBG=-1 && exit 1

debug "action: ${action}" 3

LOCKFILE="${TMPDIR}/${PROFILE}.lock"
TMPNAME="$(basename ${0%.*})"
if [ -n "${XDG_CONFIG_HOME}" ]
then
	CONFIGDIR="${XDG_CONFIG_HOME}/${TMPNAME}"
else
	CONFIGDIR="/home/${USER}/.config/${TMPNAME}"
fi

eval ${action}
ret=$?

debug "Last return-code: $?" 3

cleanup
trap - INT TERM EXIT
exit $ret
