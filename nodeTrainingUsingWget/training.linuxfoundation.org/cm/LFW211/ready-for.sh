#!/bin/bash
#
# Setup development system for Linux Foundation courses
#
# Copyright (c) 2013 Chris Simmonds <chris@2net.co.uk>
#               2013-2021 Behan Webster <behanw@converseincode.com>
#               2014-2016 Jan-Simon Möller <dl9pf@gmx.de>
#
# Licensed under GPL
#
# Originally conceived by Chris Simmonds for LF315/Android Internals
# Massive rewrite and updates by Behan Webster (Maintainer)
# Further updates by Jan-Simon Möller
#
# Version 8.34: 2021-11-16 ready-for.sh
#   - Fix a very subtle bug in the setup_meta code
#   - Fix blacklisting distributions for embedded courses
#   - Add @kernel dependency to LFD440
# 
#===============================================================================
VERSION=8.34

#===============================================================================
#
# You can define requirements for a particular course by defining the following
# variables where LFXXXX is your course number:
#
#   TITLE[LFXXXX]=""            # Name of the course
#   WEBPAGE[LFXXXX]="http://..."# LF URL for course
#   ARCH[LFXXXX]=x86_64         # Required CPU arch (optional)
#   CPUFLAGS[LFXXXX]="vmx aes"  # Required CPU flags (optional)
#   CPUS[LFXXXX]=2              # How many CPUS/cores are required
#   PREFER_CPUS[LFXXXX]=4       # How many CPUS would be preferred
#   BOGOMIPS[LFXXXX]=4000       # How many cumulative BogoMIPS you need
#   RAM[LFXXXX]=2               # How many GiB of RAM you need
#   DISK[LFXXXX]=30             # How many GiB of Disk you need free in $HOME
#   BOOT[LFXXXX]=30             # How many MiB of Disk you need free in /boot
#   CONFIGS[LFXXXX]="KSM"       # Which CONFIG_* kernel variables are required (optional)
#   DISTRO_ARCH[LFXXXX]=x86_64  # Required Linux distro arch (optional)
#   INTERNET[LFXXXX]=y          # Is internet access required? (optional)
#   NATIVELINUX[LFXXXX]=Required# Is Native Linux required for this course? (optional)
#   VMOKAY[LFXXXX]=Okay         # Can this course be done on a VM? (optional)
#   SYMLINKS[LFXXXX]="/bin/sh:!dash /usr/bin/python:!^/opt/"
#                               # Symlink patterns you want to satisfy
#   VERSIONS[LFXXXX]="bash:>4 gcc:=5 python:<3"
#                               # --versions you want to check
#   EXTRAS[LFXXXX]="LFD460_%COURSE_VERSION%/"
#                               # Download extra things from course materials
#   RUNCODE[LFXXXX]=lfXXX_func  # Run this bash function after install (optional)
#   DISTROS[LFXXXX]="Fedora-34+ CentOS-8+ Ubuntu-22.04+"
#                               # List of distros you can support.
#                               #   DistroName
#                               #   DistroName:arch
#                               #   DistroName-release
#                               #   DistroName-release+
#                               #   DistroName:arch-release
#                               #   DistroName:arch-release+
#
# Note: I know BogoMIPS aren't a great measure of CPU speed, but it's what we have
# easy access to.
#
# You can also specify required packages for your distro. All the appropriate
# package lists for the running machine will be checked. This allows you to
# keep package lists for particular distros, releases, arches and classes.
# You can also specify package groups using @names.
# For example:
#
#   PACKAGES[Ubuntu]="gcc less"
#   PACKAGES[Ubuntu_LFD420]="stress trace-cmd"
#   PACKAGES[Ubuntu-20.04]="git-core"
#   PACKAGES[Ubuntu-20.04]="git"
#   PACKAGES[Ubuntu-20.04_LFD450]="gparted u-boot-tools"
#   PACKAGES[Ubuntu_LFS550]="build-dep_wireshark"
#   PACKAGES[@kernel]="bc crash"
#   PACKAGES[Ubuntu-20.04_@kernel]="libssl-dev"
#   PACKAGES[RHEL]="gcc less"
#   PACKAGES[RHEL-7]="git"
#   PACKAGES[RHEL-7_LF320]="trace-cmd"
#
# Missing packages are listed so the user can install them manually, or you can
# rerun this script with --install to do it automatically.
#
# You can also copy the identical package list from another course with:
#
#   COPYPACKAGES[LFDXXX] = "LFDYYY"
#
# Support for all distros is not yet finished, but I've templated in code where
# possible. If you can add code to support a distro, please send a patch!
#
# If you want to see extra debug output, set DEBUG=1 2 or 3
#
#    DEBUG=2 ./ready-for.sh LFD450
# or
#    ./ready-for.sh --debug=2 LFD450
# or
#    ./ready-for.sh -DD LFD450
#

#===============================================================================
RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
CYAN="\e[0;36m"
BLUE="\e[0;34m"
BACK="\e[0m"

#===============================================================================
# Strict debugging
#set -euo pipefail
DEBUG=
FAILED=
MISSING_PACKAGES=
NO_WARN=
SIMULATE_FAILURE=
VERBOSE=
WARNINGS=

umask 002

#-------------------------------------------------------------------------------
ask() {
    echo -ne "${YELLOW}WARN${BACK}: $* " >&2
}

#-------------------------------------------------------------------------------
bare_debug() {
    [[ -z $DEBUG ]] || echo "$@" >&2
}

#-------------------------------------------------------------------------------
bug() {
    local MSG=$1 CODE=$2
    warn "Hmm... That's not right...\n    $MSG\n    Probably a bug. Please send the output of the following to behanw@converseincode.com\n      $CODE"
}

#-------------------------------------------------------------------------------
debug() {
    local LEVEL=$1; shift
    local OPT=
    if [[ $1 == -* ]] ; then
        OPT=$1; shift
    fi
    if [[ -n $DEBUG && $LEVEL -le $DEBUG ]] ; then
        # shellcheck disable=SC2086
        bare_debug $OPT "D:" "$@"
    fi
}

#-------------------------------------------------------------------------------
divider() {
    echo '---'${VERBOSE:+ $* }'-----------------------------------------------------------------------------'
}

#-------------------------------------------------------------------------------
dothis() {
    echo -e "${BLUE}$*${BACK}"
}

#-------------------------------------------------------------------------------
export MYPID=$$
error() {
    echo E: "$@" >&2
    set -e
    kill -TERM $MYPID 2>/dev/null
}

#-------------------------------------------------------------------------------
fail() {
    echo -e "${RED}FAIL${BACK}:" "$@" >&2
    FAILED=y
}

#-------------------------------------------------------------------------------
highlight() {
    echo -e "${YELLOW}$*${BACK}" >&2
}

#-------------------------------------------------------------------------------
fix_missing() {
    local MSG=$1 CMD1=$2 CMD2=$3
    highlight "$MSG by running:"
    # shellcheck disable=SC2086
    dothis "  "$CMD1
    if [[ -n $CMD2 ]] ; then
        highlight "or by:"
        # shellcheck disable=SC2086
        dothis "  "$CMD2
    fi
}

#-------------------------------------------------------------------------------
notice() {
    local OPT=
    if [[ $1 == -* ]] ; then
        OPT=$1; shift
    fi
    if [[ -n $OPT || -z $NO_WARN ]] ; then
        # shellcheck disable=SC2086
        echo $OPT -e "${CYAN}NOTE${BACK}: $*" >&2
    fi
}

#-------------------------------------------------------------------------------
pass() {
    [[ -n ${NO_PASS:-} ]] || echo -e "${GREEN}PASS${BACK}: $*"
}

#-------------------------------------------------------------------------------
progress() {
    [[ -z ${PROGRESS:-} ]] || echo -en "$1" >&2
}

#-------------------------------------------------------------------------------
verbose() {
    [[ -z $VERBOSE ]] || echo -e "INFO:" "$@" >&2
}

#-------------------------------------------------------------------------------
warn() {
    local OPT=
    if [[ $1 == -* ]] ; then
        OPT=$1; shift
    fi
    if [[ -n $OPT || -z $NO_WARN ]] ; then
        # shellcheck disable=SC2086
        echo $OPT -e "${YELLOW}WARN${BACK}: $*" >&2
    fi
}

#-------------------------------------------------------------------------------
warn_wait() {
    if [[ -n $YES ]] ; then
        debug 1 "warn_wait: always --yes, so not asking; just continue."
        return 0
    fi
    warn -n "$*\n    Continue? [Yn] " >&2
    read -r ANS
    case $ANS in
        Y*|y*|1*) return 0 ;;
        *) [[ -z $ANS ]] || return 1 ;;
    esac
    return 0
}

#===============================================================================
# Check that we're running on Linux
if [[ -e /usr/sbin/system_profiler ]] ; then
    FAILED="FAIL: This script doesn't support MacOS"
    REGEX="(ANY|UNIX)OS"
    PASS="PASS: You can take this course on MacOS"
elif grep -qi microsoft /proc/version ; then
    FAILED="FAIL: This is Windows (albeit WSL)"
    REGEX="ANYOS"
    PASS="PASS: You can take this course on Windows"
elif [[ $(uname -s) != Linux || -n $SIMULATE_FAILURE ]] ; then
    FAILED="FAIL: This script doesn't support $(uname -s)"
fi
if [[ -n $FAILED ]] ; then
    if [[ -n $REGEX ]] ; then
        for A in "$@" ; do
            [[ $A =~ ^LF ]] || continue
            if ! grep -qE -- "$A" "$0" ; then
                echo "FAIL: This is not a valid course number"
            elif grep -qE -- "^OS\\[$A\\]=\"\\\$$REGEX\"$" "$0" ; then
                echo "$PASS"
                echo "NOTE: However this setup script is only supported on Linux."
                echo "      You don't need to run it on this Operating System."
                exit 0
            fi
        done
    fi
    echo "$FAILED"
    echo "NOTE: You need to run this on the Linux machine you intend to use for the class"
    exit 1
fi

#===============================================================================
# The minimum version of bash required to run this script is bash v4
if bash --version | grep -E -q 'GNU bash, version [1-3]' ; then
    fail "This script requires at least version 4 of bash"
    fail "You are running: $(bash --version | head -1)"
    exit 1
fi

#===============================================================================
check_root() {
    if [[ $USER == root || $HOME == /root ]] ; then
        fail "Please don't run as root"
        notice "Sudo will be used internally by this script as required."
        exit 1
    fi
}
check_root

#===============================================================================
CMDNAME=${CMDNAME:-$0}
CMDBASE=$(basename "$CMDNAME")
ACTIVITYPAT="LF[CDSW]"
EXAMPLEACT="LFD450"
usage() {
    echo "Usage: $CMDBASE [options] [course[=version]]"
    echo "      --distro               List current Linux distro"
    echo "  -i  --install              Install missing packages for the course"
    echo "  --fix --fix-missing        Skip uninstallable packages"
    echo "  -f  --force-download       Redownload everything"
    echo "  -r  --remove [--all]       Remove installed packages for the course"
    echo "  -l  --list                 List all supported courses"
    echo "      --no-cache             Don't use previously cached output."
    echo "  -C  --no-course-files      Don't install course files"
    echo "  -E  --no-extras            Don't download extra materials"
    echo "  -I  --no-install           Don't check installed packages"
    echo "  -R  --no-recommends        Don't install recommended packages"
    echo "  -S  --no-suggests          Don't install suggested packages"
    echo "  -N  --no-vm                Don't download virtual machine"
    echo "      --update               Update to latest version of this script"
    echo "      --verify               Verify script MD5sum"
    echo "  -V  --version              List script version"
    echo "  -v  --verbose              Turn on extra messages"
    echo "  -y  --yes                  Answer 'yes' to every question"
    echo "  -h  --help                 What you just typed to see this"
    echo "  -H  --advanced-help        Even more esoteric options for debugging"
    echo
    # shellcheck disable=SC2086
    echo "Example: $CMDBASE --install" ${COURSE:-$EXAMPLEACT}
    echo
    echo "You can ask for a specific version of a course like this:"
    echo "         $CMDBASE $EXAMPLEACT=V2.4.3"

    if [[ -n $MORE_HELP ]] ; then
        echo
        echo "Extra help options:"
        echo "      --curl                 Force the use of curl instead of wget"
        echo "      --detect-vm            Just see if we're running in a Virtual Machine"
        echo "      --diff-distro D1 D2    Diff package lists between distros"
        echo "      --dry-run              Show what would be done (without doing it)"
        echo "  -M  --fast-mirror          Use the faster mirror site"
        echo "      --force-update         Force download a new copy of $CMDBASE"
        echo "      --gather-info          Gather information about the distro to email to the maintainer"
        echo "      --list-distro          List all possible distros"
        echo "      --no-network           Disable network check (for testing purposes)"
        echo "  -O  --override-distro D    Override automatic distro detection and set to D"
        echo "      --try-all-courses      Try running $CMDBASE for each class serially"
        echo "  -U  --user                 Override \$USER for install"
        echo
        echo "For debugging $CMDBASE"
        echo "      --strict               Strict bash debugging mode (set -euo pipefail)"
        echo "  -D  --debug                Debug messaging level 1"
        echo "  -DD --debug=2              Debug messaging level 2"
        echo "  -DDD --debug=3             Debug messaging level 3"
        echo "      --no-contract          Don't contract package lists"
        echo "      --show-lookups         Show all PACKAGE lookups for package list generation"
        echo "      --simulate-failure     Fake some failures to debug the failure path"
        echo "      --trace                Turn on bash tracing (very verbose)"
        echo
        echo "For checking packages and dependencies:"
        echo "      --check-packages CLASS Check required packages exist for distros in CLASS"
        echo "  -p  --progress             Show progress bar while checking"
        echo "  -P  --list-packages CLASS  List all required packages for distros in CLASS"
        echo "  -p  --packages PKG CLASS   List a package for all distros in CLASS"
        echo "  -L  --list-requirements CL List all requirements for CLASS"
        echo
        echo "Where CLASS can be LFDXXX or LFSXXX or one of these:"
        echo "  -A  --all                  All classes"
        echo "  -AD --all-lfd              All Development classes"
        echo "  -AS --all-lfs              All SysAdmin classes"
    fi

    exit 0
}

#===============================================================================
# Default command option flags
ALL_ACTIVITIES=
ALL_LFD=
ALL_LFS=
ALL_PKGS=
CHECK_PKGS=
CHECK_WEB=
COURSE=
CVER=
DETECT_VM=
DIFF_DIST=
DIST_LIST=
DONTUPDATE=
DRYRUN=
FASTMIRROR=
FIXMISSING=
FORCEUPDATE=
FORCEDLOAD=
GATHER_INFO=
GRAPHVIZ=
INSTALL=
JSON=
LIST_ACTIVITIES=
LIST_DISTROS=
LIST_PKGS=
LIST_REQS=
MORE_HELP=
NOCACHE=
NOCM=
NOCONTRACT=
NOEXTRAS=
NOINSTALL=
NONETWORK=
NORECOMMENDS=
NOSUGGESTS=
NOVM=
PKGS=
PROGRESS=
REMOVE=
SHOWLOOKUPS=
TRY_ALL_ACTIVITIES=
UPDATE=
USECURL=
VERIFY=
WHICH_DISTRO=
YES=

#===============================================================================
# Command option parsing
CMDOPTS="$*"
while [[ $# -gt 0 ]] ; do
    case "$1" in
        -AD|-ALFD|--all-lfd) ALL_LFD=y ;;
        -AS|-ALFS|--all-lfs) ALL_LFS=y ;;
        -A|--all|--all-courses) ALL_ACTIVITIES=y ;;
        -ap|--all-packages) ALL_PKGS=y ;;
        --check-packages) CHECK_PKGS=y ;;
        --check-web*) CHECK_WEB=y ;;
        --curl) USECURL=y ;;
        -D|--debug=1|--debug) DEBUG=1; VERBOSE=y ;;
        -DD|--debug=2) DEBUG=2; VERBOSE=y ;;
        -DDD|--debug=3) DEBUG=3; VERBOSE=y ;;
        --detect-vm) DETECT_VM=y ;;
        --diff|--diff-distro) DIFF_DIST="$2,$3"; shift; shift ;;
        --distro) WHICH_DISTRO=y ;;
        --dry-run|--dryrun) DRYRUN="echo" ;;
        -i|--install) INSTALL=y ;;
        --fix*|--skip*) FIXMISSING=y;;
        -M|--fast-mirror) FASTMIRROR=y ;;
        -f|--force|--force-download) FORCEDLOAD=y; NOCACHE=y ;;
        --force-update) FORCEUPDATE=y ;;
        --gather-info) GATHER_INFO=y ;;
        --graphiz|--dot) if [[ -n ${2:-} && -d $2 ]] ; then GRAPHVIZ=$2; shift; else GRAPHVIZ=y; fi ;;
        --json) JSON=y ;;
        -l|--list) LIST_ACTIVITIES=y; break ;;
        --list-distro*) LIST_DISTROS=y; break ;;
        -P|--list-packages) LIST_PKGS=y ;;
        -L|--list-requirements) LIST_REQS=y ;;
        --no-cache|--nocache) NOCACHE=y ;;
        --no-contract) NOCONTRACT=y ;;
        -C|--no-course-files) NOCM=y ;;
        -E|--no-extras) NOEXTRAS=y ;;
        -I|--no-install) NOINSTALL=y ;;
        --no-network) NONETWORK=y; DONTUPDATE=y ;;
        -R|--no-recommends) NORECOMMENDS=y ;;
        -S|--no-suggests) NOSUGGESTS=y ;;
        -N|--no-vm*) NOVM=y ;;
        -O|--override-distro) DIST_LIST=$2; shift ;;
        -p|--packages) LIST_PKGS=y; PKGS="${PKGS# } $2"; shift ;;
        -r|--remove) REMOVE=y ;;
        --progress) PROGRESS=y ;;
        --show-lookups) SHOWLOOKUPS=y ;;
        --simulate-failure) SIMULATE_FAILURE=y; NOCACHE=y ;;
        --strict) set -euo pipefail ;;
        --trace) set -x ;;
        --try-all-courses) TRY_ALL_ACTIVITIES=y ;;
        --update-*) UPDATE=${1#--update-}; VERIFY=''; VERBOSE=y ;;
        --update) UPDATE=y; VERBOSE=y ;;
        --verify-*) UPDATE=''; VERIFY=${1#--verify-} ;;
        --verify) VERIFY=y ;;
        -U|--user) USER=$2; HOME=$(getent passwd "$2" | cut -d: -f6); shift ;;
        -v|--verbose) VERBOSE=y ;;
        -V|--version) echo $VERSION; exit 0 ;;
        -y|--yes) YES=y ;;
        v[0-9.]*|V[0-9.]*) CVER=${1^^} ;;
        $ACTIVITYPAT*|Coursera) COURSE="${COURSE# } $1" ;;
        [0-9][0-9][0-9]) COURSE="${COURSE# } LFD$1" ;;
        -H|--advanced-help) MORE_HELP=y; usage ;;
        -h*|--help*|*) usage ;;
    esac
    shift
done
PKGS="${PKGS# }"
debug 1 "main: Command Line Parameters: CMD=$CMDNAME => $CMDOPTS ($PKGS)"
debug 1 "main: COURSE=$COURSE $(env | grep '=y$') CVER=$CVER"

#===============================================================================
CONFFILE="$HOME/.${CMDBASE%.sh}.rc"
if [[ -f $CONFFILE ]] ; then
    notice "Reading $CONFFILE"
    # shellcheck disable=SC1090
    source "$CONFFILE"
fi

#===============================================================================
# Allow info to be gathered in order to fix distro detection problems
gather() {
    local FILE
    FILE=$(command -v "$1" 2>/dev/null || echo "$1")
    shift
    if [[ -n $FILE && -e $FILE ]] ; then
        echo "--- $FILE ---------------------------------------------"
        if [[ -x $FILE ]] ; then
            "$FILE" "$@"
        else
            cat "$FILE"
        fi
    fi
}

#===============================================================================
# Gather information to send to script maintainer about this computer for debugging
gather_info() {
    gather /bin/bash --version
    gather uname -a
    gather lscpu
    gather /proc/cpuinfo
    gather free
    gather /proc/meminfo
    gather lsb_release --all
    gather /etc/lsb-release
    gather /etc/os-release
    gather /etc/debian_version
    gather /etc/apt/sources.list
    gather /etc/redhat-release
    gather /etc/SuSE-release
    gather /etc/arch-release
    gather /etc/gentoo-release
    divider
    exit 0
}
[[ -z $GATHER_INFO ]] || gather_info

#===============================================================================
# Just in case we're behind a proxy server (the system will add settings to /etc/environment)
if [[ -f /etc/environment ]] ; then
    source /etc/environment
fi
export all_proxy http_proxy https_proxy ftp_proxy

#===============================================================================
# See if version is less than the other
version_greater_equal() {
    local i LEN VER1 VER2
    IFS=. read -r -a VER1 <<< "$1"
    IFS=. read -r -a VER2 <<< "$2"
    # shellcheck disable=SC2145
    debug 3 "version_greater_equal: $1(${#VER1[*]})=>[${VER1[@]}] $2(${#VER2[*]})=>[${VER2[@]}]"
    LEN=$( (( ${#VER1[*]} > ${#VER2[*]} )) && echo ${#VER1[*]} || echo ${#VER2[*]})
    #echo "VER1[0] => ${VER1[0]}"
    #echo "VER2[0] => ${VER2[0]}"
    for ((i=0; i<LEN; i++)) ; do
        VER1[i]=${VER1[i]:-0}; VER1[i]=${VER1[i]#0};
        VER2[i]=${VER2[i]:-0}; VER2[i]=${VER2[i]#0};
        debug 3 "  version_greater_equal: Compare ${VER1[i]} and ${VER2[i]}"
        if (( ${VER1[i]:-0} > ${VER2[i]:-0} )) ; then
            return 0
        elif (( ${VER1[i]:-0} < ${VER2[i]:-0} )) ; then
            return 1
        fi
    done
    return 0
}

#===============================================================================
# See if md5sum is the same
md5cmp() {
    local FILE=$1 MD5=$2
    debug 3 "md5cmp FILE=$FILE MD5=$MD5"
    [[ $MD5 = $(md5sum "$FILE" | awk '{print $1}') ]] || return 1
    return 0
}

#===============================================================================
CMCACHE="$HOME/.cache/${CMDBASE%.sh}"

#===============================================================================
# Clean meta variable cache
clean_cache() {
    debug 1 "clean_cache: $CMCACHE"
    mkdir -p "$CMCACHE"
    chmod 775 "$CMCACHE"
    find "$CMCACHE" -mtime +0 -type f -print0 | xargs -0 --no-run-if-empty rm -f
    rm -f "$CMCACHE/*.conf"
}
clean_cache

#===============================================================================
cache_output() {
    local ACTIVITY="$1"
    local CMD="$2"
    local OUTPUT="$CMCACHE/$ACTIVITY-${CMDBASE%.sh}.output"
    debug 1 "cache_output: ACTIVITY=$ACTIVITY CMD=$CMD OUTPUT=$OUTPUT"

    mkdir -p "$CMCACHE"
    chmod 775 "$CMCACHE"

    if [[ -n $NOCACHE || -n $VERBOSE ]] ; then
        "$CMD"
        rm -f "$OUTPUT"
    elif [[ -s $OUTPUT ]] ; then
        if grep -q FAIL "$OUTPUT" ; then FAILED=y; fi
        if grep -q WARN "$OUTPUT" ; then WARNINGS=y; fi
        cat "$OUTPUT"
    else
        "$CMD" 2>&1 | tee "$OUTPUT"
    fi
}

#===============================================================================
# URLS
LFURL="https://training.linuxfoundation.org"
BACKUPURL="https://cm.converseincode.com"
LFCM="$LFURL/cm"
UPGRADE="$LFCM/prep"
LFDTRAINING="$LFURL/linux-courses/training"
LFSTRAINING="$LFURL/linux-courses/training"
VMURL="VIRTUAL_MACHINE_IMAGES"

CMUSERNAME=LFtraining
CMPASSWORD=Penguin2014
WGET_PASS="--user=$CMUSERNAME --password=$CMPASSWORD"
CURL_PASS="--user $CMUSERNAME:$CMPASSWORD"

#===============================================================================
WGET_VERSION=$(wget --version | awk '{print $3; exit}')
WGET_PROGRESS="--quiet --progress=bar"
WGET_TIMEOUT="--timeout=10"

if version_greater_equal "$WGET_VERSION" 1.17 ; then
    WGET_PROGRESS="$WGET_PROGRESS --show-progress"
fi

CURL_TIMEOUT="--location --connect-timeout 10"

#===============================================================================
# Download file (try wget, then curl, then perl)
get() {
    local URL=$1 WGET_OPTS=${2:-} CURL_OPTS=${3:-}
    if [[ -n $NONETWORK ]] ; then
        warn "get: Can't access $URL because no-network selected."
        return 1
    elif [[ -z $USECURL ]] && command -v wget >/dev/null ; then
        debug 2 "  get: wget --quiet --no-cache --no-check-certificate $WGET_TIMEOUT $WGET_OPTS $URL"
        # shellcheck disable=SC2086
        $DRYRUN wget --quiet --no-cache $WGET_TIMEOUT $WGET_OPTS "$URL" -O- 2>/dev/null || return 1
    elif command -v curl >/dev/null ; then
        debug 2 "  get: curl $CURL_TIMEOUT $CURL_OPTS $URL"
        # shellcheck disable=SC2086
        $DRYRUN curl $CURL_TIMEOUT $CURL_OPTS "$URL" 2>/dev/null || return 1
    elif command -v perl >/dev/null ; then
        debug 2 "  perl LWP::Simple $URL"
        $DRYRUN perl -MLWP::Simple -e "getprint '$URL'" 2>/dev/null || return 1
    else
        warn "No download tool found."
        return 1
    fi
    return 0
}


#===============================================================================
# Are we close enough to having the clock set to global time? (The Bones check)
check_time() {
    #local IP=$(curl "https://ifconfig.co")
    #local TZ=$(curl "https:/ipapi.co/$IP/timezone")
    #local TO=$(curl "https:/ipapi.co/$IP/utc_offset")
    local OUTSIDE HERE DIFF

    local TIMESTAMP="$CMCACHE/time.okay"
    if [[ -z $SIMULATE_FAILURE && -f $TIMESTAMP ]] ; then
        return 0
    fi

    if [[ -n $NONETWORK ]] ; then
        warn "get: Can't check time because no-network selected."
        return 1
    elif [[ -z $USECURL ]] && command -v wget >/dev/null ; then
        OUTSIDE=$(wget -q -O- "http://worldtimeapi.org/api/ip" | sed -e 's/^.*unixtime"://; s/,.*$//')
    elif command -v curl >/dev/null ; then
        OUTSIDE=$(curl -s "http://worldtimeapi.org/api/ip" | sed -e 's/^.*unixtime"://; s/,.*$//')
    else
        warn "get: Can't check time because there are no usable command line web tools."
        return 1
    fi

    [[ -z $SIMULATE_FAILURE ]] || OUTSIDE="<html>"
    if [[ -z $OUTSIDE || $OUTSIDE =~ [a-zA-Z] ]] ; then
        warn "I can't read an external time source, so I can't check that the computer has a valid time set"
        debug "$OUTPUT"
        return
    fi

    HERE=$(date +"%s")
    #[[ -z $SIMULATE_FAILURE ]] || HERE=$(( OUTSIDE + 6 * 60 ))
    DIFF=$(( OUTSIDE - HERE ))
    debug 1 "OUTSIDE:$OUTSIDE HERE:$HERE DIFF:$DIFF"

    # Allow for a +/- 5min offset for a sloppy clock
    if [[ $DIFF -gt 300 || $DIFF -lt -300 ]] ; then
        fail "The time on this computer is likely broken which may make installing packages or downloading files fail"
        dothis "Please fix your date/time and try this script again"
        exit 1
    fi
    [[ -n $PROGRESS ]] || pass "The time on this computer seems set reasonably close to global time"
    touch "$TIMESTAMP"
}

check_time


RETRY=
WGET_CM_OPTS="$WGET_PASS --no-check-certificate --timestamping $WGET_TIMEOUT"
CURL_CM_OPTS="$CURL_PASS $CURL_TIMEOUT"

RANDOMNUM=$(dd if=/dev/urandom count=1 2>/dev/null | md5sum | awk '{print $1}')

#===============================================================================
get_urls() {
    URL=$1
    if [[ -n $FASTMIRROR && ( $URL =~ tar || $URL =~ mp4 ) ]] ; then
        notice "Using fast mirror for $URL"
        echo "$BACKUPURL/$URL"
        echo "$LFCM/$URL"
    else
        echo "$LFCM/$URL"
        [[ -z "$RETRY" ]] || echo "$BACKUPURL/$URL"
    fi
}

#===============================================================================
# Get File from web site
get_file() {
    local ACTIVITY=${1%/}
    local FILE=${2:-}
    local TO=${3:-}
    local PARTIAL=${4:-}
    local GET=${5:-}
    debug 1 "get_file ACTIVITY=$ACTIVITY FILE=$FILE TO=$TO PARTIAL=$PARTIAL"

    # shellcheck disable=SC2155
    local URLS=$(get_urls "$ACTIVITY${FILE:+/$FILE}${GET:+?s=$RANDOMNUM}")
    local TOFILE=
    local RET=0

    if [[ -n $TO ]] ; then
        if [[ -d $TO ]] ; then
            pushd "$TO" >/dev/null
        else
            TOFILE="$TO"
        fi
    fi
    debug 1 "get_file URL=$URL TOFILE=$TOFILE"

    if [[ -n $NONETWORK ]] ; then
        warn "get_file: Can't access $FILE because no-network selected."
        RET=1
    elif [[ -z $USECURL ]] && command -v wget >/dev/null ; then
        local OPTS=''
        if [[ -n $FILE ]] ; then
            OPTS="--continue $WGET_PROGRESS"
        else
            OPTS="--quiet -O ${TOFILE:--}"
        fi
        for URL in $URLS ; do
            debug 2 "  get_file: wget $WGET_CM_OPTS $OPTS $URL"
            # shellcheck disable=SC2086
            if $DRYRUN wget $WGET_CM_OPTS $OPTS "$URL" ; then
                break
            fi
        done
    elif command -v curl >/dev/null ; then
        local OPTS='-s'
        if [[ -n $FILE ]] ; then
            OPTS="-# -O"
            if [[ $PARTIAL = y ]] ; then
                rm -f "$FILE"
            elif [[ -z $PARTIAL && -f $FILE ]] ; then
                notice "Verifying $FILE... (for curl)"
                tar tf "$FILE" >/dev/null 2>&1 || rm -f "$FILE"
            fi
        fi
        if [[ -n $TOFILE ]] ; then
            OPTS+=" --output=$TOFILE"
        fi
        for URL in $URLS ; do
            debug 2 "  get_file: curl $CURL_CM_OPTS $OPTS $URL"
            # shellcheck disable=SC2086
            if [[ ! -f $FILE ]] ; then
                if $DRYRUN curl $CURL_CM_OPTS $OPTS "$URL" ; then
                    break
                fi
            fi
        done
    else
        warn "No download tool found."
        RET=1
    fi
    if [[ -n $TO && -d $TO ]] ; then
        popd >/dev/null
    fi
    return "$RET"
}

#===============================================================================
# Try to get file
try_file() {
    local ACTIVITY=${1%/}
    local FILE=$2
    local TODIR=$3
    debug 1 "try_file ACTIVITY=$ACTIVITY FILE=$FILE TODIR=$TODIR"

    local URLS URL SIZE
    for URL in $(get_urls "$ACTIVITY${FILE:+/$FILE}") ; do
        debug 2 "  try_file: wget --quiet $WGET_CM_OPTS $URL"
        # shellcheck disable=SC2086
        SIZE=$(wget --server-response --spider --quiet $WGET_CM_OPTS "$URL" 2>&1 | awk '/Content-Length:/ {print $2}' | tail -1) && break
    done

    local LOCALFILE="$TODIR/$FILE"
    debug 2 "  try_file: LOCALFILE=$LOCALFILE"
    if [[ -f $LOCALFILE && $(stat --format="%s" "$LOCALFILE") -eq $SIZE ]] ; then
        debug 1 "Already downloaded $LOCALFILE"
        return 1
    fi
    return 0
}

#===============================================================================
# Get meta variable (cache lookups)
get_var(){
    local KEY=$1
    local ACTIVITY=${2# }
    debug 1 "get_var: KEY=$KEY ACTIVITY=$ACTIVITY"

    mkdir -p "$CMCACHE"
    local CONF="${CMDBASE%.sh}.conf"
    local FILE="$CMCACHE/$ACTIVITY-$CONF"
    debug 2 "  get_var: CONF=$CONF FILE=$FILE"
    get_file "$ACTIVITY/.$CONF" '' "$FILE" '' 1 \
        || get_file ".$ACTIVITY-$CONF" '' "$FILE" '' 1
    (set +e; grep -Ee "^$KEY=" "$FILE" | sed -e 's/^.*=//; s/^"\(.*\)"$/\1/')
}

#===============================================================================
# Get Version
get_file_version() {
    local FILE=$1
    sed -re 's/^.*(V[0-9.]+).*$/\1/' <<<"$FILE"
}

#===============================================================================
# Get Extras
get_activity_file() {
    local ACTIVITY=$1
    local KIND=${2:-SOLUTIONS}
    local VER=${3:-}
    debug 1 "get_activity_file: ACTIVITY=$ACTIVITY KIND=$KIND VER=$VER"
    local FILE VER FORCED_KIND

    if [[ -n $NONETWORK ]] ; then
        warn "get_activity_file: Can't get activity files because no-network selected."
        return 0
    fi

    FORCED_KIND=$(get_var "$KIND" "$ACTIVITY")
    if [[ -n $FORCED_KIND ]] ; then
        KIND="$FORCED_KIND"
    fi

    # Find newest SOLUTIONS file
    # shellcheck disable=SC2086
    FILE=$(get_file "$ACTIVITY" \
        | awk -F\" '/'${VER:+_V${VER#V}_}$KIND'/ {print $8}' \
        | sed -Ee 's/^(.*V)([0-9.]+)(_.*)$/\2.0.0 \1\2\3/' \
        | sort -t. -n -k1,1 -k2,2 -k3,3 \
        | awk 'END {print $2}')
    # shellcheck disable=SC2086
    if [[ -z $FILE ]] ; then
        FILE=$(get_file "$ACTIVITY" \
        | awk -F\" '/'$KIND'/ {print $8}' \
        | sort | tail -1)
    fi

    if [[ -n $FILE ]] ; then
        VER=$(get_file_version "$FILE")
        debug 2 "   get_activity_file: ACTIVITY=$ACTIVITY FILE=$FILE VER=$VER"
        echo "$FILE" "$VER"
    else
        debug 2 "   get_activity_file: No files found for $ACTIVITY"
    fi
}


#===============================================================================
# Indicates whether Internet connectivity has been found
INTERNET_AVAILABLE=
PINGHOST="8.8.8.8"

#===============================================================================
# Check for updates
# As a side effect of finding the version will determine if INTERNET_AVAILABLE
check_version() {
    verbose "Checking for updated script"
    [[ -z $DONTUPDATE ]] || return 0

    if [[ -n $NONETWORK ]] ; then
        warn "check_version: Can't check version because no-network selected."
        return 0
    fi

    local URL="$UPGRADE"
    local CMD="$CMDBASE"
    local META="${CMD/.sh/}.meta"
    local NEW="${TMPDIR:-/tmp}/${CMD/.sh/.$$}"

    #---------------------------------------------------------------------------
    # Beta update
    if [[ $UPDATE =~ ...* || $VERIFY =~ ...* ]] ; then
        if [[ $UPDATE =~ ...* ]] ; then
            URL+="/$UPDATE"
        elif [[ $VERIFY =~ ...* ]] ; then
            URL+="/$VERIFY"
        fi
        FORCEUPDATE=y
    fi

    #---------------------------------------------------------------------------
    if [[ -z $SIMULATE_FAILURE ]] && ping -q -c 1 "$PINGHOST" >/dev/null 2>&1 ; then
        INTERNET_AVAILABLE=y
    else
        debug "check_version: The internet doesn't appear to be available"
        return
    fi

    #---------------------------------------------------------------------------
    # Get metadata
    local VER MD5 OTHER
    # shellcheck disable=SC2046,SC2086
    read -r VER MD5 OTHER <<< "$(get $URL/$META?$(date +%s))"

    #---------------------------------------------------------------------------
    # Verify metadata
    if [[ -n $VERIFY ]] ; then
        if [[ -n $MD5 ]] ; then
            if md5cmp "$CMDNAME" "$MD5" ; then
                pass "md5sum matches"
            elif md5cmp "$CMDNAME" "$OTHER" ; then
                MD5="$OTHER"
                pass "md5sum matches"
            else
                fail "md5sum failed (you might want to run a --force-update to re-download)"
            fi
#        elif [[ -z $VER ]] ; then
#            return 0
        else
            warn "md5sum can't be checked, none found"
        fi
        exit 0
    fi

    #---------------------------------------------------------------------------
    # Get update for script
    debug 1 "  check_version: ver:$VERSION VER:$VER MD5:$MD5"
    [[ -z $FORCEUPDATE ]] || UPDATE=y
    if [[ -n $FORCEUPDATE ]] || ( ! md5cmp "$CMDNAME" "$MD5" && ! version_greater_equal "$VERSION" "$VER" ) ; then
        if [[ -n $UPDATE ]] ; then
            if get "$URL/$CMD" >"$NEW" ; then
                mv "$NEW" "$CMDNAME"
                chmod 755 "$CMDNAME"
                if [[ $UPDATE =~ ...* ]] ; then
                    warn "Now running $UPDATE version of this script"
                else
                    notice "A new version of this script was found. Upgrading..."
                    # shellcheck disable=SC2086
                    [[ -z $COURSE ]] || DONTUPDATE=1 eval bash "$CMDNAME" $CMDOPTS
                fi
            else
                rm -f "$NEW"
                warn "No script found"
            fi
        else
            notice "A new version of this script was found. (use \"$CMDNAME --update\" to download)"
        fi
    else
        verbose "No update found"
    fi
    [[ -z $UPDATE ]] || exit 0
}
check_version

#===============================================================================
# Make associative arrays
declare -A DEBREL DISTRO_ALIASES DISTRO_NAMES FALLBACK PACKAGES

#===============================================================================
# Create empty Package lists for all distros
#===============================================================================
PACKAGES[AlmaLinux]=
PACKAGES[AlmaLinux-8]=
#-------------------------------------------------------------------------------
PACKAGES[ArchLinux]=
#-------------------------------------------------------------------------------
PACKAGES[CentOS]=
PACKAGES[CentOS-7]=
PACKAGES[CentOS-8]=
PACKAGES[CentOS.Stream]=
PACKAGES[CentOS.Stream-8]=
#-------------------------------------------------------------------------------
PACKAGES[Debian]=
PACKAGES[Debian-9]=
PACKAGES[Debian-10]=
PACKAGES[Debian-11]=
PACKAGES[Debian-999]=
#-------------------------------------------------------------------------------
PACKAGES[Fedora]=
PACKAGES[Fedora-33]=
PACKAGES[Fedora-34]=
PACKAGES[Fedora-35]=
PACKAGES[Fedora-999]=
#-------------------------------------------------------------------------------
PACKAGES[LinuxMint]=
PACKAGES[LinuxMint-19.3]=
PACKAGES[LinuxMint-20.1]=
#-------------------------------------------------------------------------------
PACKAGES[openSUSE]=
PACKAGES[openSUSE-15.2]=
PACKAGES[openSUSE-15.3]=
PACKAGES[openSUSE-999]=
#-------------------------------------------------------------------------------
PACKAGES[OracleLinux]=
#-------------------------------------------------------------------------------
PACKAGES[RHEL]=
PACKAGES[RHEL-7]=
PACKAGES[RHEL-8]=
#-------------------------------------------------------------------------------
PACKAGES[RockyLinux]=
PACKAGES[RockyLinux-8]=
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu]=
PACKAGES[Ubuntu-18.04]=
PACKAGES[Ubuntu-20.04]=
PACKAGES[Ubuntu-21.10]=
#-------------------------------------------------------------------------------
PACKAGES[SLES]=
PACKAGES[SLES-15]=

#===============================================================================
# If we can't find settings/packages for a distro fallback to the next one
FALLBACK=(
    [AlmaLinux]="RHEL CentOS"
    [AlmaLinux-8]="RHEL-8 CentOS-8 RHEL CentOS"
    [amzn]="CentOS-7 CentOS"
    [amzn-2.0]="CentOS-7 CentOS"
    [CentOS]="RHEL"
    [CentOS-7]="RHEL-7 RHEL CentOS"
    [CentOS-8]="RHEL-8 RHEL CentOS"
    [CentOS.Stream]="CentOS RHEL"
    [CentOS.Stream-8]="RHEL-8 RHEL CentOS-8 CentOS"
    [Debian]="Ubuntu"
    [Debian-9]="Ubuntu-18.04 Debian"
    [Debian-10]="Debian-9 Ubuntu-20.04 Debian Ubuntu"
    [Debian-11]="Debian-10 Ubuntu-20.04 Debian Ubuntu"
    [Debian-999]="Debian-11 Ubuntu-20.04 Debian Ubuntu"
    [Fedora]="RHEL CentOS"
    [Fedora-33]="Fedora RHEL CentOS"
    [Fedora-34]="Fedora-33 Fedora"
    [Fedora-35]="Fedora-34 Fedora"
    [Fedora-999]="Fedora-35 Fedora"
    [LinuxMint]="Ubuntu"
    [LinuxMint-19.3]="LinuxMint-19.2 Ubuntu-18.04 Ubuntu"
    [LinuxMint-20.1]="LinuxMint-19.3 Ubuntu-20.04 Ubuntu"
    [Mint]="LinuxMint Ubuntu"
    [RHEL]="CentOS"
    [RHEL-7]="CentOS-7 RHEL CentOS"
    [RHEL-8]="CentOS-8 RHEL CentOS"
    [RockyLinux]="RHEL CentOS"
    [RockyLinux-8]="RHEL-8 CentOS-8 RHEL CentOS"
    [openSUSE-15.2]="openSUSE"
    [openSUSE-15.3]="openSUSE-15.2 openSUSE"
    [openSUSE-999]="openSUSE-15.2 openSUSE"
    [SLES]="openSUSE"
    [SLES-15]="openSUSE-15.2 openSUSE"
    [SUSE]="openSUSE"
    [Ubuntu]="Debian"
    [Ubuntu-18.04]="Debian-9 Debian Ubuntu"
    [Ubuntu-20.04]="Debian-10 Debian Ubuntu-18.04 Ubuntu"
    [Ubuntu-21.10]="Ubuntu-20.04 Ubuntu Debian-11 Debian"
    [Kubuntu]="Ubuntu Debian"
    [XUbuntu]="Ubuntu Debian"
)

#===============================================================================
# Distro release aliases
DISTRO_ALIASES=(
    [CentOS-6-]="CentOS-5 CentOS-6"
    [CentOS-7-]="CentOS-5 CentOS-6 CentOS-7"
    [Debian-8-]="Debian-6 Debian-7 Debian-8"
    [Debian-9-]="Debian-7 Debian-8 Debian-9"
    [Debian-sid]="Debian-999"
    [Fedora-31-]="Fedora-23 Fedora-24 Fedora-25 Fedora-26 Fedora-27 Fedora-28 Fedora-29 Fedora-30 Fedora-31"
    [Fedora-Rawhide]="Fedora-999"
    [LinuxMint-18.3-]="LinuxMint-16 LinuxMint-17 LinuxMint-18 LinuxMint-18.1 LinuxMint-18.2 LinuxMint-18.3"
    [openSUSE-Tumbleweed]="openSUSE-999"
    [RHEL-6-]="RHEL-5 RHEL-6"
    [RHEL-7-]="RHEL-5 RHEL-6 RHEL-7"
    [SLES-12.2-]="SLES-12.1 SLES-12.2"
    [Ubuntu-LTS]="Ubuntu-18.04 Ubuntu-20.04"
    [Ubuntu-18.04+LTS]="Ubuntu-18.04 Ubuntu-20.04"
    [Ubuntu-18.04+LTS+]="Ubuntu-18.04 Ubuntu-20.04+"
    [Ubuntu-20.04+LTS]="Ubuntu-20.04"
    [Ubuntu-20.04+LTS+]="Ubuntu-20.04+"
    [Ubuntu-17.10-]="Ubuntu-12.04 Ubuntu-12.10 Ubuntu-13.04 Ubuntu-13.10 Ubuntu-14.04 Ubuntu-14.10 Ubuntu-15.04 Ubuntu-15.10 Ubuntu-16.04 Ubuntu-16.10 Ubuntu-17.04 Ubuntu-17.10"
    [Ubuntu-19.10-]="Ubuntu-12.04 Ubuntu-12.10 Ubuntu-13.04 Ubuntu-13.10 Ubuntu-14.04 Ubuntu-14.10 Ubuntu-15.04 Ubuntu-15.10 Ubuntu-16.04 Ubuntu-16.10 Ubuntu-17.04 Ubuntu-17.10 Ubuntu-18.10 Ubuntu-19.04 Ubuntu-19.10"
    [Ubuntu-21.04-]="Ubuntu-12.04 Ubuntu-12.10 Ubuntu-13.04 Ubuntu-13.10 Ubuntu-14.04 Ubuntu-14.10 Ubuntu-15.04 Ubuntu-15.10 Ubuntu-16.04 Ubuntu-16.10 Ubuntu-17.04 Ubuntu-17.10 Ubuntu-18.10 Ubuntu-19.04 Ubuntu-19.10 Ubuntu-20.10 Ubuntu-21.04"
)

#===============================================================================
# Distro release code names
DISTRO_NAMES=(
    [Debian-999]="Debian-sid"
    [Fedora-999]="Fedora-Rawhide"
    [openSUSE-999]="openSUSE-Tumbleweed"
)

#===============================================================================
# Distro release code names
DEBREL=(
    [hamm]=2
    [slink]=2.1
    [potato]=2.2
    [woody]=3
    [sarge]=3.1
    [etch]=4
    [lenny]=5
    [squeeze]=6
    [wheezy]=7
    [jessie]=8
    [stretch]=9
    [buster]=10
    [bullseye]=11
    [bookworm]=12
    [trixie]=13
    [stable]=11
    [testing]=12
    [sid]=999
    [unstable]=999
)

#===============================================================================
# Some classes have been renamed
declare -A ACTIVITY_ALIASES
ACTIVITY_ALIASES=(
    [LFD211]=LFD301
    [LFD262]=LFD301
    [LFD305]=LFD301
    [LFD312]=LFD401
    [LFD320]=LFD420
    [LFD331]=LFD430
    [LFD404]=LFD460
    [LFD405]=LFD460
    [LFD410]=LFD450
    [LFD411]=LFD450
    [LFD5420]=LFD420
    [LFS101x]=LFS101
    [LFS103x]=LFS103
    [LFS158x]=LFS158
    [LFS163x]=LFS163
    [LFS164x]=LFS164
    [LFS102]=LFS300
    [LFS220]=LFS301
    [LFS230]=LFS311
    [LFS520]=LFS452
    [LFS540]=LFS462
    [LFS541]=LFS462
    [LFS550]=LFS465
    [LFS551]=LFS465
)

#===============================================================================
distrib_list() {
    for D in ${!PACKAGES[*]}; do
        echo "$D"
    done | sed -e 's/_.*$//' | grep -- - | sort -u
}
ALL_DISTS=$(distrib_list)
# shellcheck disable=SC2086
debug 1 "ALL_DISTS: "$ALL_DISTS

#===============================================================================
check_distros() {
    local DISTS
    DISTS=$(distrib_list)

    if [[ $DISTS != "$ALL_DISTS" ]] ; then
        # shellcheck disable=SC2086
        warn "ALL_DISTS: "$ALL_DISTS
        # shellcheck disable=SC2086
        warn "DISTS_NOW: "$DISTS
        error "More distros were added in package lists in error"
    fi
}

#===============================================================================
declare -A ARCH BOGOMIPS BOOT CONFIGS COPYPACKAGES CPUFLAGS CPUS \
    DISK DISTROS DISTRO_ARCH DISTRO_BL DISTRO_DEFAULT EMBEDDED EXTRAS \
    INPERSON INSTR_LED_CLASS INTERNET MOOC NATIVELINUX OS OS_NEEDS PREFER_CPUS \
    PREREQ RAM RECOMMENDS RUNCODE SELFPACED SELFPACED_CLASS SUGGESTS SYMLINKS \
    TITLE VERSIONS VIRTUAL VMOKAY VMS WEBPAGE

#===============================================================================
# Default Requirements
#===============================================================================
ARCH=
BOGOMIPS=2000
BOOT=128
CONFIGS=
COPYPACKAGES=
CPUFLAGS=
CPUS=1
DISK=5
#DISTROS=
DISTROS[EMBEDDED]="ArchLinux AlmaLinux-8+ CentOS-8+ Debian-10+ Fedora-33+ LinuxMint-20+ openSUSE-15+ RockyLinux-8+ Ubuntu-20.04+LTS+"
DISTROS[LFD]="ArchLinux AlmaLinux-8+ CentOS-8+ Debian-10+ Fedora-33+ LinuxMint-19+ openSUSE-15+ RHEL-8+ RockyLinux-8+ Ubuntu-18.04+LTS+ SLES-15+"
DISTROS[LFS]="AlmaLinux-8+ CentOS-7+ Debian-9+ Fedora-33+ LinuxMint-19+ openSUSE-15+ RHEL-7+ RockyLinux-8+ Ubuntu-18.04+LTS+ SLES-15+"
DISTRO_ARCH=
DISTRO_BL="CentOS-6- Debian-8- Fedora-32- LinuxMint-18.3- openSUSE-42.3- OracleLinux RHEL-6- SLES-12.2- Ubuntu-21.04-"
DISTRO_BL[EMBEDDED]="CentOS-7- Debian-9- 5 Fedora-32- LinuxMint-18.3- openSUSE-42.3- OracleLinux RHEL SLES Ubuntu-18.04 Ubuntu-21.04-"
export DISTRO_DEFAULT=
DISTRO_DEFAULT[LFD]="Ubuntu-20.04"
DISTRO_DEFAULT[LFS]="CentOS-8"
EMBEDDED=n
EXTRAS=
#INCLUDES=
INPERSON=y
INSTR_LED_CLASS=
INTERNET=
MOOC=
NATIVELINUX=
OS=Linux
OS_NEEDS=
PACKAGES=
PREFER_CPUS=2
#PREREQ=    # Can't initialize PREREQ or graphiz is broken
RAM=1
RECOMMENDS=
RUNCODE=
SELFPACED=n
SELFPACED_CLASS=
SUGGESTS=
SYMLINKS=
#TITLE=    # Can't initialize TITLE or it is listed as a course
VERSIONS=
VIRTUAL=y
VMOKAY=Acceptable
VMS=
WEBPAGE=

#===============================================================================
# Remove shellcheck errors
export OS_NEEDS

#===============================================================================
ANYOS="Linux, MacOS, Windows"
#UNIXOS="Linux, MacOS"
BROWSER="modern web browser"
REMOTE_NEEDS="$BROWSER, terminal emulation program (ssh or putty)"
GCP="Firefox browser and a Google Cloud Platform (GCP) account"
FREEGCP="Google Cloud Platform (GCP) free tier account"
VAGRANTVB="Vagrant and VirtualBox"
#BBBKIT="devboard, usb-serial, card-reader, usb-ethernet, SD-card"
#BBBKITIMG="$BBBKIT:BBB_kit"
#BBBLCDKIT="$BBBKIT, LCD-screen"
#BBBLCDKITIMG="$BBBLCDKIT:LCD_kit"

#===============================================================================
# Common strings
DISCOURAGED="Highly Discouraged"
RECOMMENDED="Highly Recommended"
REQUIRED="Required"
#VMPREFERRED="The use of a VM for this class is preferable"
VMNOTOKAY="This course cannot be run from a VM. You will be running VMs as a host machine"

#===============================================================================
enable_extras() {
    local ACTIVITY=$1

    EXTRAS[$ACTIVITY]="${ACTIVITY}_%COURSE_VERSION%/"
}


#===============================================================================
# Build packages
#===============================================================================
PACKAGES[@build]="autoconf automake bison flex gdb libtool make patch patchutils"
RECOMMENDS[@build]="ccache texinfo"
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu_@build]="build-essential libc6-dev libtool-bin manpages manpages-dev"
PACKAGES[Debian-10_@build]="[Ubuntu-20.04_@build]"
#-------------------------------------------------------------------------------
PACKAGES[RHEL_@build]="gcc gcc-c++ glibc-devel glibc-utils"
#-------------------------------------------------------------------------------
PACKAGES[openSUSE_@build]="[RHEL_@build] makeinfo -texinfo"

#===============================================================================
# LLVM packages
#===============================================================================
PACKAGES[@clang]="llvm clang"
PACKAGES[Debian_@clang]="build-essential pkg-config libssl-dev"
PACKAGES[RHEL_@clang]="openssl-devel"

#===============================================================================
# Common packages used in various places
#===============================================================================
PACKAGES[@common]="bzip2 curl dos2unix file gawk git gzip psmisc sudo tar tree
	unzip wget"
RECOMMENDS[@common]="rsync screen zip"
SUGGESTS[@common]="emacs gnome-tweaks gparted mc nano net-tools open-vm-tools"
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu_@common]="emacs-gtk gnupg gnupg2 iputils-ping tofrodos xz-utils"
PACKAGES[Debian-9_@common]="-emacs-gtk"
PACKAGES[Ubuntu-18.04_@common]="[Debian-9_@common]"
RECOMMENDS[Ubuntu_@common]="aptitude htop synaptic unp"
SUGGESTS[Ubuntu_@common]="diffuse vim"
SUGGESTS[Ubuntu-20.04_@common]="-diffuse"
SUGGESTS[Debian-9_@common]="-gnome-tweaks gnome-tweak-tool"
SUGGESTS[Debian-10_@common]="-"
SUGGESTS[Debian-11_@common]="-diffuse"
#-------------------------------------------------------------------------------
PACKAGES[RHEL_@common]="gnupg2"
SUGGESTS[RHEL_@common]="vim-enhanced"
SUGGESTS[RHEL-7_@common]="[RHEL_@common] -gnome-tweaks gnome-tweak-tool"
SUGGESTS[RHEL-8_@common]="[RHEL_@common]"
PACKAGES[Fedora_@common]="NetworkManager-tui xz"
RECOMMENDS[Fedora_@common]="[RHEL_@common]"
#-------------------------------------------------------------------------------
PACKAGES[openSUSE_@common]="gpg2 xz"
RECOMMENDS[openSUSE_@common]="mlocate"
SUGGESTS[openSUSE_@common]="net-tools-deprecated vim"
SUGGESTS[openSUSE-15.2_@common]="-gnome-tweaks"

#===============================================================================
# Docker packages
#===============================================================================
PACKAGES[Debian_@docker]="-"
PACKAGES[Debian-10_@docker]="docker.io"
PACKAGES[Debian-999_@docker]="docker.io"
PACKAGES[Ubuntu_@docker]="docker.io"
PACKAGES[Fedora-33_@docker]="[RHEL_@docker]"
PACKAGES[openSUSE_@docker]="docker"
PACKAGES[RHEL_@docker]="podman podman-docker"
PACKAGES[RHEL-7_@docker]="-podman -podman-docker docker-common"

#===============================================================================
# eBPF related packages
#===============================================================================
PACKAGES[Debian_@ebpf]="bpfcc-tools"
PACKAGES[Debian-9_@ebpf]="-bpfcc-tools"
PACKAGES[Fedora_@ebpf]="bcc bcc-tools"
PACKAGES[CentOS_@ebpf]="[Fedora_@ebpf]"
PACKAGES[CentOS-7_@ebpf]="-bcc -bcc-tools"
PACKAGES[openSUSE_@ebpf]="bcc-tools"

#===============================================================================
# Embedded packages
#===============================================================================
PACKAGES[@embedded]="bc gperf lzop python3-pip screen"
SUGGESTS[@embedded]="minicom"
#-------------------------------------------------------------------------------
SUGGESTS[Fedora_@embedded]="cutecom"
PACKAGES[CentOS_@embedded]="dnsmasq dtc glibc-static libyaml-devel nfs-utils"
PACKAGES[CentOS-7_@embedded]="-dtc"
RECOMMENDS[CentOS_@embedded]="bmap-tools"
RECOMMENDS[CentOS-7_@embedded]="uboot-tools -bmap-tools"
RECOMMENDS[Fedora_@embedded]="bmap-tools"
#-------------------------------------------------------------------------------
PACKAGES[openSUSE_@embedded]="dtc nfs-kernel-server"
RECOMMENDS[openSUSE_@embedded]="u-boot-tools"
SUGGESTS[openSUSE_@embedded]="cutecom"
PACKAGES[openSUSE-999_@embedded]="-python3-pip"
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu_@embedded]="dnsmasq-base dosfstools eject libyaml-dev mtd-utils
	nfs-kernel-server parted"
PACKAGES[Ubuntu-18.04_@embedded]="libgconf-2-4"
PACKAGES[Ubuntu-20.04_@embedded]="libgconf-2-4"
RECOMMENDS[Ubuntu_@embedded]="bmap-tools device-tree-compiler u-boot-tools"
SUGGESTS[Ubuntu_@embedded]="cutecom"
RECOMMENDS[LinuxMint-20.1_@embedded]="[@Ubuntu_@embedded]"

#===============================================================================
# Java packages
#===============================================================================
PACKAGES[@java]=""
PACKAGES[Debian_@java]="default-jdk"
PACKAGES[Debian-9_@java]="openjdk-8-jdk"
PACKAGES[Debian-10_@java]="openjdk-11-jdk"
PACKAGES[RHEL_@java]="java-1.8.0-openjdk"
PACKAGES[Fedora_@java]="[REL_@java] java-11-openjdk"
PACKAGES[openSUSE_@java]="java-1_8_0-openjdk java-11-openjdk"

#===============================================================================
# Kernel dump related packages
#===============================================================================
PACKAGES[@kdump]="crash kexec-tools"
#-------------------------------------------------------------------------------
PACKAGES[Debian_@kdump]="kdump-tools"
PACKAGES[Ubuntu_@kdump]="[Debian_@kdump] linux-crashdump"
#-------------------------------------------------------------------------------
PACKAGES[openSUSE_@kdump]="kdump yast2-kdump"

#===============================================================================
# Kernel related packages
#===============================================================================
PACKAGES[@kernel]="@build bc crash cscope gitk sysfsutils indent"
#-------------------------------------------------------------------------------
PACKAGES[Debian_@kernel]="exuberant-ctags libelf-dev libfuse-dev libhugetlbfs-dev
	libncurses-dev libssl-dev liblzo2-dev nfs-common swig"
RECOMMENDS[Debian_@kernel]="sparse symlinks"
SUGGESTS[Debian_@kernel]="libglade2-dev libgtk2.0-dev libslang2-dev"
PACKAGES[Debian-9_@kernel]="qt5-default -libncurses-dev libncurses5-dev
	-libhugetlbfs-dev"
PACKAGES[Debian-11_@kernel]="-qt5-default"
RECOMMENDS[Debian_@kernel]="libhugetlbfs-dev"
PACKAGES[Ubuntu-18.04_@kernel]="-libncurses-dev libncurses5-dev"
#-------------------------------------------------------------------------------
PACKAGES[RHEL_@kernel]="ctags elfutils-libelf-devel fuse-devel kernel-devel
	ncurses-devel openssl-devel"
RECOMMENDS[RHEL_@kernel]="libhugetlbfs-devel nfs-utils sparse qt-devel"
RECOMMENDS[RHEL-8_@kernel]="-sparse qt5-devel"
RECOMMENDS[Fedora_@kernel]="[RHEL_@kernel] -libhugetlbfs-devel"
SUGGESTS[RHEL_@kernel]="gtk2-devel libglade2-devel qt-devel slang-devel"
SUGGESTS[RHEL-8_@kernel]="-libglade2-devel -qt-devel qt5-devel"
#-------------------------------------------------------------------------------
PACKAGES[openSUSE_@kernel]="ctags fuse-devel kernel-devel libelf-devel lzo-devel
	libopenssl-devel ncurses-devel"
RECOMMENDS[openSUSE_@kernel]="libhugetlbfs sparse"
SUGGESTS[openSUSE_@kernel]="gtk2-devel libglade2-devel slang-devel"
RECOMMENDS[openSUSE-999_@kernel]="libhugetlbfs-devel"

#===============================================================================
# Perf related packages
#===============================================================================
PACKAGES[Debian_@perf]="binutils-dev libaudit-dev libdw-dev libelf-dev
	liblzma-dev libslang2-dev libssl-dev libunwind-dev libzstd-dev zlib1g-dev"
PACKAGES[Debian-9_@perf]="-"
RECOMMENDS[Debian_@perf]="libaio-dev libnuma-dev libperl-dev libpython3-dev"
SUGGESTS[Debian_@perf]="libgtk2.0-dev"
#-------------------------------------------------------------------------------
PACKAGES[RHEL_@perf]="binutils-devel libdwarf-devel elfutils-libelf-devel
	slang-devel openssl-devel libunwind-devel libzstd-devel zlib-devel"
RECOMMENDS[RHEL_@perf]="libaio-devel perl-devel"
RECOMMENDS[RHEL-8_@perf]="platform-python-devel"
SUGGESTS[RHEL_@perf]="gtk2-devel"
#-------------------------------------------------------------------------------
PACKAGES[openSUSE_@perf]="binutils-devel audit-devel libdw-devel libelf-devel
	slang-devel libopenssl-devel libunwind-devel libzstd-devel zlib-devel"
RECOMMENDS[openSUSE_@perf]="libaio-devel libnuma-devel"
SUGGESTS[openSUSE_@perf]="gtk2-devel"

#===============================================================================
# QEMU arm packages
#===============================================================================
PACKAGES[@qemu]="@build ninja-build"
PACKAGES[Ubuntu_@qemu]="libglib2.0-dev libpixman-1-dev libpython3-dev meson zlib1g-dev"
PACKAGES[LinuxMint-20.1_@qemu]="libglib2.0-dev libpixman-1-dev"
PACKAGES[RHEL_@qemu]="glib2-devel pixman-devel SDL2-devel zlib-devel"
PACKAGES[RHEL-8_@qemu]="platform-python-devel"
PACKAGES[Fedora_@qemu]="python3-devel"
RECOMMENDS[Fedora_@qemu]="perl-ExtUtils-MakeMaker"
PACKAGES[openSUSE_@qemu]="-ninja-build ninja"

#===============================================================================
# QEMU arm packages
#===============================================================================
PACKAGES[@qemuarm]="qemu-system-arm"
PACKAGES[CentOS-7_@qemuarm]="-qemu-system-arm"
PACKAGES[CentOS-8_@qemuarm]="-qemu-system-arm"
PACKAGES[openSUSE_@qemuarm]="-qemu-system-arm"
RECOMMENDS[Ubuntu_@qemuarm]="gcc-arm-linux-gnueabihf libc6-dev-armhf-cross"
PACKAGES[Debian-9_@qemuarm]="-"
PACKAGES[Debian-10_@qemuarm]="-"

#===============================================================================
# QEMU riscv64 packages
#===============================================================================
PACKAGES[Debian_@qemuriscv]="qemu-system-misc gcc-riscv64-linux-gnu libc6-dev-riscv64-cross"
PACKAGES[Debian-9_@qemuriscv]="-gcc-riscv64-linux-gnu -libc6-dev-riscv64-cross"
PACKAGES[Fedora_@qemuriscv]="gcc-riscv64-linux-gnu"
PACKAGES[CentOS_@qemuriscv]="-"

#===============================================================================
# Stress packages
#===============================================================================
PACKAGES[@stress]="stress stress-ng"
PACKAGES[RHEL-7_@stress]="-stress-ng"
PACKAGES[RHEL-8_@stress]="-stress -stress-ng"
PACKAGES[openSUSE_@stress]="-stress"

#===============================================================================
# Sysadm related packages
#===============================================================================
PACKAGES[@sysadm]="bonnie++ collectl dstat gnuplot libtool m4 mdadm memtest86+
	mlocate sysstat"
PACKAGES[Fedora_@sysadm]="-dstat"
PACKAGES[RHEL-8_@sysadm]="[Fedora_@sysadm] -bonnie++ -collectl"
PACKAGES[Ubuntu_@sysadm]="iftop"
PACKAGES[openSUSE_@sysadm]="bonnie termcap"

#===============================================================================
# Trace/perf related packages
#===============================================================================
PACKAGES[@trace]="iotop kernelshark strace trace-cmd"
PACKAGES[Debian_@trace]="linux-perf ltrace"
PACKAGES[Debian-9_@trace]="-"
PACKAGES[Ubuntu_@trace]="[Debian_@trace] -linux-perf linux-tools-generic"
PACKAGES[RHEL_@trace]="perf"
PACKAGES[RHEL-7_@trace]="-kernelshark"
PACKAGES[Fedora_@trace]="perf"
PACKAGES[openSUSE_@trace]="perf"
PACKAGES[openSUSE-999_@trace]="-kernelshark"

#===============================================================================
# Virt related packages
#===============================================================================
PACKAGES[@virt]="bridge-utils ebtables qemu-kvm virt-manager virt-viewer"
PACKAGES[Debian_@virt]="libosinfo-bin libvirt-daemon-system libvirt-clients \
	qemu-utils spice-client-gtk virtinst"
PACKAGES[Debian-9_@virt]="-"
PACKAGES[Debian-11_@virt]="-qemu-kvm"
PACKAGES[Ubuntu_@virt]="[Debian_@virt]"
PACKAGES[Ubuntu-18.04_@virt]="libvirt-bin"
PACKAGES[Ubuntu-20.04_@virt]="-"
PACKAGES[Ubuntu-21.10_@virt]="-qemu-kvm"
PACKAGES[RHEL_@virt]="libvirt libvirt-client spice-gtk-tools virt-install"
PACKAGES[RHEL-7_@virt]="-spice-gtk"
PACKAGES[RHEL-8_@virt]="-bridge-utils -ebtables"
PACKAGES[Fedora_@virt]="-ebtables"
PACKAGES[openSUSE_@virt]="[RHEL_@virt] libvirt-daemon spice-gtk -spice-gtk-tools"


#===============================================================================
# Extra requirements for LFD110
#===============================================================================
TITLE[LFD110]="Introduction to RISC-V"
WEBPAGE[LFD110]="$LFDTRAINING/introduction-to-riscv-lfd110"
INPERSON[LFD110]=n
VIRTUAL[LFD110]=n
SELFPACED[LFD110]=y
MOOC[LFD110]=edX
#-------------------------------------------------------------------------------
#OS[LFD110]="$ANYOS"
#OS_NEEDS[LFD110]="$REMOTE_NEEDS"
CPUS[LFD110]=2
PREFER_CPUS[LFD110]=4
RAM[LFD110]=2
INTERNET[LFD110]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFD110]="@build bc curl gawk git gperf"
PACKAGES[Debian_LFD110]="libmpc-dev libmpfr-dev libgmp-dev zlib1g-dev libexpat1-dev"
PACKAGES[CentOS_LFD110]="libmpc-devel mpfr-devel gmp-devel zlib-devel expat-devel"
PACKAGES[Fedora_LFD110]="[CentOS_LFD110]"
PACKAGES[openSUSE_LFD110]="libmpc3 mpfr-devel gmp-devel zlib-devel libexpat-devel"

#===============================================================================
# Extra requirements for LFD111
#===============================================================================
TITLE[LFD111]="Building a RISC-V CPU Core"
WEBPAGE[LFD111]="$LFDTRAINING/building-a-riscv-cpu-core-lfd111x"
INPERSON[LFD111]=n
VIRTUAL[LFD111]=n
SELFPACED[LFD111]=y
MOOC[LFD111]=edX
#-------------------------------------------------------------------------------
OS[LFD111]="$ANYOS"
OS_NEEDS[LFD111]="$BROWSER"
#-------------------------------------------------------------------------------
INTERNET[LFD111]="$REQUIRED"

#===============================================================================
# Extra requirements for LFD132
#===============================================================================
TITLE[LFD132]="Introduction to Cloud Foundry"
WEBPAGE[LFD132]="$LFDTRAINING/introduction-to-cloud-foundry-lfd132x"
INPERSON[LFD132]=n
VIRTUAL[LFD132]=n
SELFPACED[LFD132]=y
MOOC[LFD132]=edX
INTERNET[LFD132]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFD132]="$ANYOS"
OS_NEEDS[LFD132]="$BROWSER"

#===============================================================================
# Extra requirements for LFD133
#===============================================================================
TITLE[LFD133]="Introduction to WebAssembly"
WEBPAGE[LFD133]="$LFDTRAINING/introduction-to-webassembly-lfd133"
INPERSON[LFD133]=n
VIRTUAL[LFD133]=n
SELFPACED[LFD133]=y
MOOC[LFD133]=edX
#-------------------------------------------------------------------------------
OS[LFD133]="$ANYOS"
OS_NEEDS[LFD133]="$REMOTE_NEEDS"
#-------------------------------------------------------------------------------
INTERNET[LFD133]="$REQUIRED"

#===============================================================================
# Extra requirements for LFD134
#===============================================================================
TITLE[LFD134]="WebAssembly Actors: From Cloud to Edge"
WEBPAGE[LFD134]="$LFDTRAINING/webassembly-actors-from-cloud-to-edge-lfd134x"
INPERSON[LFD134]=n
VIRTUAL[LFD134]=n
SELFPACED[LFD134]=y
MOOC[LFD134]=edX
#-------------------------------------------------------------------------------
OS[LFD134]="$ANYOS"
OS_NEEDS[LFD134]="$REMOTE_NEEDS"
#-------------------------------------------------------------------------------
INTERNET[LFD134]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFD134]="@clang"

#===============================================================================
# Extra requirements for LFD201
#===============================================================================
TITLE[LFD201]="Intro to Open Source Development, Git, and Linux"
WEBPAGE[LFD201]="$LFDTRAINING/introduction-to-open-source-development-git-and-linux"
INPERSON[LFD201]=n
VIRTUAL[LFD201]=n
SELFPACED[LFD201]=y
#-------------------------------------------------------------------------------
INTERNET[LFD201]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFD201]="LFD301"

#===============================================================================
# Extra requirements for Coursera (essentially LFD201)
#===============================================================================
TITLE[Coursera]="Open Source Software Development, Linux and Git"
WEBPAGE[Coursera]="$LFDTRAINING/introduction-to-open-source-development-git-and-linux"
INPERSON[Coursera]=n
VIRTUAL[Coursera]=n
SELFPACED[Coursera]=y
MOOC[Coursera]=Coursera
#-------------------------------------------------------------------------------
INTERNET[Coursera]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[Coursera]="LFD301"

#===============================================================================
# Extra requirements for LFD232
#===============================================================================
TITLE[LFD232]="Cloud Foundry for Developers"
WEBPAGE[LFD232]="$LFDTRAINING/cloud-foundry-for-developers"
INSTR_LED_CLASS[LFD232]="LFD432"
INPERSON[LFD232]=n
VIRTUAL[LFD232]=n
SELFPACED[LFD232]=y
#-------------------------------------------------------------------------------
OS[LFD232]="$ANYOS"
OS_NEEDS[LFD232]="$REMOTE_NEEDS, Cloud Foundry CLI"
#-------------------------------------------------------------------------------
INTERNET[LFD232]="$REQUIRED"
COPYPACKAGES[LFD232]="LFS132"


#===============================================================================
# Extra requirements for LFD254
#===============================================================================
TITLE[LFD254]="Containers for Developers and Quality Assurance"
WEBPAGE[LFD254]="$LFDTRAINING/containers-for-developers-and-quality-assurance"
INPERSON[LFD254]=n
VIRTUAL[LFD254]=n
SELFPACED[LFD254]=y
#-------------------------------------------------------------------------------
OS[LFD254]="$ANYOS"
OS_NEEDS[LFD254]="$REMOTE_NEEDS, Google Cloud Account, Docker Desktop"
CPUS[LFD254]=4
PREFER_CPUS[LFD254]=4
RAM[LFD254]=8
DISK[LFD254]=10
#-------------------------------------------------------------------------------
INTERNET[LFD254]="$REQUIRED"
PACKAGES[LFD254]="@docker"

#===============================================================================
# Extra requirements for LFD259
#===============================================================================
TITLE[LFD259]="Kubernetes for Developers"
WEBPAGE[LFD259]="$LFDTRAINING/kubernetes-for-developers"
INPERSON[LFD259]=n
VIRTUAL[LFD259]=n
SELFPACED[LFD259]=y
#-------------------------------------------------------------------------------
OS[LFD259]="$ANYOS"
OS_NEEDS[LFD259]="$REMOTE_NEEDS, Kubernetes CLI (kubectl)"
INTERNET[LFD259]="$REQUIRED"

#===============================================================================
# Extra requirements for LFD272
#===============================================================================
TITLE[LFD272]="Hyperledger Fabric Fundamentals for Developers"
WEBPAGE[LFD272]="$LFDTRAINING/hyperledger-fabric-for-developers-lfd272"
PREREQ[LFD272]="LFS171"
INPERSON[LFD272]=n
VIRTUAL[LFD272]=n
SELFPACED[LFD272]=y
INTERNET[LFD272]="$REQUIRED"
#-------------------------------------------------------------------------------
CPUS[LFD272]=1
PREFER_CPUS[LFD272]=2
RAM[LFD272]=2
DISTROS[LFD272]="Ubuntu-18.04+LTS+"

#===============================================================================
# Extra requirements for LFD301
#===============================================================================
TITLE[LFD301]="Introduction to Linux for Developers and GIT"
WEBPAGE[LFD301]="$LFDTRAINING/introduction-to-linux-open-source-development-and-git"
INTERNET[LFD301]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFD301]="@build @common @java @stress @sysadm @trace 
	cvs gparted lvm2 subversion sysstat tcpdump wireshark"
RECOMMENDS[LFD301]="iptraf-ng gnome-system-monitor ksysguard yelp"
PACKAGES[Debian_LFD301]="git-cvs git-daemon-sysvinit git-gui git-svn gitk gitweb
	libcurl4-openssl-dev libexpat1-dev libssl-dev"
PACKAGES[RHEL_LFD301]="git-all expat-devel openssl-devel"
PACKAGES[RHEL-8_LFD301]="-cvs"
RECOMMENDS[RHEL-6_LFD301]="-iptraf-ng iptraf kdebase -ksysguard ksysguardd"
RECOMMENDS[RHEL-8_LFD301]="-ksysguard"
PACKAGES[Fedora_LFD301]="[RHEL_LFD301]"
RECOMMENDS[Fedora_LFD301]="[RHEL_LFD301]"
RECOMMENDS[openSUSE_LFD301]="-ksysguard"
RECOMMENDS[openSUSE-15.2]="kdebase4-workspace"
RECOMMENDS[openSUSE-15.3]="-"

#===============================================================================
# Extra requirements for LFD401
#===============================================================================
TITLE[LFD401]="Developing Applications for Linux"
WEBPAGE[LFD401]="$LFDTRAINING/developing-applications-for-linux"
#-------------------------------------------------------------------------------
PACKAGES[LFD401]="@build @common valgrind ddd sysstat"
PACKAGES[Ubuntu_LFD401]="electric-fence kcachegrind libaio-dev"
PACKAGES[RHEL_LFD401]="ElectricFence glibc-static libaio-devel"
PACKAGES[RHEL-8_LFD401]="-ddd -ElectricFence"
PACKAGES[Fedora_LFD401]="[RHEL_LFD401] kcachegrind"
PACKAGES[openSUSE_LFD401]="libaio-devel kcachegrind"
PACKAGES[openSUSE-999_LFD401]="-ddd"

#===============================================================================
# Extra requirements for LFD420
#===============================================================================
TITLE[LFD420]="Linux Kernel Internals and Development"
WEBPAGE[LFD420]="$LFDTRAINING/linux-kernel-internals-and-development"
BOOT[LFD420]=128	# Room for 2 more kernels
DISK[LFD420]=9
#VMOKAY[LFD420]="$VMPREFERRED"
#-------------------------------------------------------------------------------
PACKAGES[LFD420]="@common @kernel @perf @stress @trace"

#===============================================================================
# Extra requirements for LFD430
#===============================================================================
TITLE[LFD430]="Developing Linux Device Drivers"
WEBPAGE[LFD430]="$LFDTRAINING/developing-linux-device-drivers"
PREREQ[LFD430]="LFD420"
BOOT[LFD430]=128	# Room for 2 more kernels
DISK[LFD430]=9
#VMOKAY[LFD430]="$VMPREFERRED"
#-------------------------------------------------------------------------------
PACKAGES[LFD430]="[LFD420]"

#===============================================================================
# Extra requirements for LFD435
#===============================================================================
TITLE[LFD435]="Embedded Linux Device Drivers"
WEBPAGE[LFD435]="$LFDTRAINING/developing-embedded-linux-device-drivers"
PREREQ[LFD435]="LFD420"
BOOT[LFD435]=128	# Room for 2 more kernels
DISK[LFD435]=20
CONFIGS[LFD435]="BRIDGE TUN"
#NATIVELINUX[LFD435]="$RECOMMENDED"
#VMOKAY[LFD435]="$DISCOURAGED"
DISTROS[LFD435]="${DISTROS[EMBEDDED]}"
DISTRO_BL[LFD435]="${DISTRO_BL[EMBEDDED]}"
EMBEDDED[LFD435]=y
# shellcheck disable=SC2034
#INCLUDES[LFD435]="$BBBKITIMG"
#-------------------------------------------------------------------------------
PACKAGES[LFD435]="[LFD420] @embedded @qemu @qemuriscv"

#===============================================================================
# Extra requirements for LFD440
#===============================================================================
TITLE[LFD440]="Linux Kernel Debugging and Security"
WEBPAGE[LFD440]="$LFDTRAINING/linux-kernel-debugging-and-security"
PREREQ[LFD440]="LFD420 LFD430"
BOOT[LFD440]=128	# Room for 2 more kernels
DISK[LFD440]=9
#VMOKAY[LFD440]="$VMPREFERRED"
#-------------------------------------------------------------------------------
PACKAGES[LFD440]="[LFD420] @ebpf @kernel @kdump"
PACKAGES[Ubuntu_LFD440]="policycoreutils"
#RECOMMENDS[Ubuntu_LFD440]="libdw-dev libaudit-dev libelf-dev binutils-dev
	#libnuma-dev liblzma-dev"

#===============================================================================
# Extra requirements for LFD450
#===============================================================================
TITLE[LFD450]="Embedded Linux Development"
WEBPAGE[LFD450]="$LFDTRAINING/embedded-linux-development"
PREREQ[LFD450]="LFD435"
#ARCH[LFD450]=x86_64
CPUS[LFD450]=2
PREFER_CPUS[LFD450]=4
BOGOMIPS[LFD450]=5000
RAM[LFD450]=6
DISK[LFD450]=40
CONFIGS[LFD450]="BRIDGE TUN"
INTERNET[LFD450]="$REQUIRED"
#NATIVELINUX[LFD450]="$RECOMMENDED"
#VMOKAY[LFD450]="$DISCOURAGED"
DISTROS[LFD450]="${DISTROS[EMBEDDED]}"
DISTRO_BL[LFD450]="${DISTRO_BL[EMBEDDED]}"
EMBEDDED[LFD450]=y
#INCLUDES[LFD450]="$BBBKITIMG"
#-------------------------------------------------------------------------------
PACKAGES[LFD450]="@build @common @embedded @kernel @qemu @qemuriscv @trace help2man rsync"
PACKAGES[Ubuntu_LFD450]="squashfs-tools"

#===============================================================================
# Extra requirements for LFD459
#===============================================================================
TITLE[LFD459]="Kubernetes for App Developers"
WEBPAGE[LFD459]="$LFDTRAINING/kubernetes-for-app-developers"
SELFPACED_CLASS[LFS458]="LFS259"
#-------------------------------------------------------------------------------
# shellcheck disable=SC2034
OS[LFD459]="$ANYOS"
OS_NEEDS[LFD459]="$REMOTE_NEEDS"
INTERNET[LFD459]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFD459]="LFD259"

#===============================================================================
# Extra requirements for LFD460
#===============================================================================
TITLE[LFD460]="Building Embedded Linux with the Yocto Project"
WEBPAGE[LFD460]="$LFDTRAINING/embedded-linux-development-with-yocto-project"
PREREQ[LFD460]="LFD450"
CPUS[LFD460]=4
PREFER_CPUS[LFD460]=8
BOGOMIPS[LFD460]=20000
RAM[LFD460]=4
DISK[LFD460]=100
INTERNET[LFD460]="$REQUIRED"
NATIVELINUX[LFD460]="$RECOMMENDED"
VMOKAY[LFD460]="$DISCOURAGED"
DISTROS[LFD460]="Ubuntu:amd64-20.04"
DISTRO_BL[LFD460]="${DISTRO_BL[EMBEDDED]} Arch Gentoo"
EMBEDDED[LFD460]=y
# shellcheck disable=SC2034
#INCLUDES[LFD460]="$BBBKITIMG"
SYMLINKS[LFD460]="/usr/bin/python:!^/opt/"
enable_extras "LFD460"
#-------------------------------------------------------------------------------
PACKAGES[LFD460]="@build @common @embedded @kernel chrpath cpio diffstat
	python3-jinja2 python3-pexpect python3-pip python3-ply socat xmlto xterm"
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu_LFD460]="daemon gcc-multilib libarchive-dev libegl1-mesa
	libglib2.0-dev libxml2-utils mesa-common-dev pylint3 python3-git
	libsdl2-dev python3 python3-progressbar python3-subunit
	sqlite3 xsltproc"
RECOMMENDS[Ubuntu_LFD460]="default-jre python3-git libegl1-mesa"
PACKAGES[Ubuntu-18.04_LFD460]="-libnfs8 libnfs11"
PACKAGES[Ubuntu-20.04_LFD460]="-pylint3 pylint -libnfs12 libnfs13"
PACKAGES[Ubuntu-21.10_LFD460]="[Ubuntu-20.04_LFD460]"
PACKAGES[Debian-9_LFD460]="libnfs8"
PACKAGES[Debian-10_LFD460]="libnfs12"
PACKAGES[Debian-11_LFD460]="libnfs13 -pylint3 pylint"
PACKAGES[RHEL_LFD460]="cpp daemonize diffutils libarchive-devel mesa-libGL-devel
	perl-Data-Dumper perl-Text-ParseWords perl-Thread-Queue
	rpcgen perl tar SDL2-devel sqlite which xz"
PACKAGES[RHEL-7_LFD460]="-python3-jinja2 -python3-pexpect -python3-ply -rpcgen"
PACKAGES[RHEL-8_LFD460]="-daemonize python3-GitPython"
PACKAGES[Fedora_LFD460]="cpp diffutils findutils
	libarchive-devel perl perl-bignum python3 python3-pexpect python3-GitPython
	python3-pip python3-ply python3-subunit SDL2-devel which"
PACKAGES[openSUSE_LFD460]="libarchive-devel libnfs8 libSDL-devel Mesa-dri-devel
	Mesa-libEGL1 rpcgen python3 python3-curses -python3-jinja2 python3-Jinja2
	python3-curses which"
PACKAGES[openSUSE-999_LFD460]="-libnfs8 libnfs13 python -python3 -python3-curses
	-python3-Jinja2 -python3-pexpect -python3-pip -python3-ply"

#===============================================================================
#=== End of LFD Course Definitions =============================================
#===============================================================================


check_distros


#===============================================================================
# Extra requirements for LFC110
#===============================================================================
TITLE[LFC110]="Fundamentals of Professional Open Source Management"
WEBPAGE[LFC110]="$LFSTRAINING/fundamentals-of-professional-open-source-management-lfc110"
INPERSON[LFC110]=n
VIRTUAL[LFC110]=n
SELFPACED[LFC110]=y
#-------------------------------------------------------------------------------
OS[LFC110]="$ANYOS"
VMOKAY[LFC110]=-
INTERNET[LFC110]="$REQUIRED"


#===============================================================================
# Extra requirements for LFS101
#===============================================================================
TITLE[LFS101]="Introduction to Linux"
WEBPAGE[LFS101]="$LFSTRAINING/introduction-to-linux"
INPERSON[LFS101]=n
VIRTUAL[LFS101]=n
SELFPACED[LFS101]=y
MOOC[LFS101]=edX
INTERNET[LFS101]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFS101]="@common @sysadm qpdf"

#===============================================================================
# Extra requirements for LFS143
#===============================================================================
TITLE[LFS143]="Introduction to Service Mesh with Linkerd"
WEBPAGE[LFS143]="$LFSTRAINING/introduction-to-service-mesh-with-linkerd-lfs143"
INPERSON[LFS143]=n
VIRTUAL[LFS143]=n
SELFPACED[LFS143]=y
MOOC[LFS143]=edX
INTERNET[LFS143]="$REQUIRED"
ARCH[LFS143]="x86_64"
#-------------------------------------------------------------------------------
OS[LFS143]="$ANYOS"
OS_NEEDS[LFS143]="docker, docker-engine, kubectl, kind/k3s"
#-------------------------------------------------------------------------------
CPUS[LFS143]=2
PREFER_CPUS[LFS143]=4
BOGOMIPS[LFS143]=4000
RAM[LFS143]=2
DISK[LFS143]=50
VMOKAY[LFS143]="$VMNOTOKAY"
#-------------------------------------------------------------------------------
PACKAGES[LFS143]="@common, @docker"

#===============================================================================
# Extra requirements for LFS151
#===============================================================================
TITLE[LFS151]="Introduction to Cloud Infrastructure Technologies"
WEBPAGE[LFS151]="$LFSTRAINING/introduction-to-cloud-infrastructure-technologies"
INPERSON[LFS151]=n
VIRTUAL[LFS151]=n
SELFPACED[LFS151]=y
MOOC[LFS151]=edX
INTERNET[LFS151]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFS151]="@common"

#===============================================================================
# Extra requirements for LFS153
#===============================================================================
TITLE[LFS153]="Building Microservice Platforms with TARS"
WEBPAGE[LFS153]="https://www.edx.org/course/introduction-to-tars-course-v1linuxfoundationxlfs153x2t2020"
INPERSON[LFS153]=n
VIRTUAL[LFS153]=n
SELFPACED[LFS153]=y
RAM[LFS153]=2
MOOC[LFS153]=edX
INTERNET[LFS153]="$REQUIRED"
#-------------------------------------------------------------------------------
#OS[LFS153]="$ANYOS"
PACKAGES[LFS153]="@build @docker @java cmake git golang nodejs php"
PACKAGES[Debian_LFS153]="default-mysql-server"
PACKAGES[Fedora_LFS153]="community-mysql-server"
PACKAGES[CentOS_LFS153]="mysql-server"
PACKAGES[CentOS-7_LFS153]="-mysql-server"
PACKAGES[openSUSE_LFS153]="-golang -nodejs -php"
PACKAGES[openSUSE-15.2_LFS153]="nodejs12"
PACKAGES[openSUSE-999_LFS153]="-nodejs12 nodejs-default"

#===============================================================================
# Extra requirements for LFS156
#===============================================================================
TITLE[LFS156]="Introduction to Kubernetes on Edge with K3s"
WEBPAGE[LFS156]="$LFSTRAINING/introduction-to-kubernetes-on-edge-with-k3s-lfs156x/"
INPERSON[LFS156]=n
VIRTUAL[LFS156]=n
SELFPACED[LFS156]=y
CPUS[LFS156]=2
PREFER_CPUS[LFS156]=4
BOGOMIPS[LFS156]=3000
CPUFLAGS[LFS156]="svm|vmx"
RAM[LFS156]=8
DISK[LFS156]=50
ARCH[LFS156]="x86_64"
DISTRO_ARCH[LFS156]="x86_64"
DISTROS[LFS156]="Ubuntu-20.04+LTS"
DISTRO_DEFAULT[LFS156]="Ubuntu-20.04"
MOOC[LFS156]=edX
INTERNET[LFS156]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFS156]="@docker"

#===============================================================================
# Extra requirements for LFS157
#===============================================================================
TITLE[LFS157]="Introduction to Serverless on Kubernetes"
WEBPAGE[LFS157]="https://www.edx.org/course/introduction-to-serverless-on-kubernetes-course-v1linuxfoundationxlfs157x3t2020"
INPERSON[LFS157]=n
VIRTUAL[LFS157]=n
SELFPACED[LFS157]=y
CPUS[LFS157]=2
PREFER_CPUS[LFS157]=4
BOGOMIPS[LFS157]=3000
CPUFLAGS[LFS157]="svm|vmx"
RAM[LFS157]=8
DISK[LFS157]=20
ARCH[LFS157]="x86_64"
DISTRO_ARCH[LFS157]="x86_64"
DISTROS[LFS157]="Ubuntu-20.04+LTS"
DISTRO_DEFAULT[LFS157]="Ubuntu-20.04"
MOOC[LFS157]=edX
INTERNET[LFS157]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFS157]="@docker"

#===============================================================================
# Extra requirements for LFS158
#===============================================================================
TITLE[LFS158]="Introduction to Kubernetes"
WEBPAGE[LFS158]="$LFSTRAINING/introduction-to-kubernetes"
INSTR_LED_CLASS[LFS158]="LFS458"
INPERSON[LFS158]=n
VIRTUAL[LFS158]=n
SELFPACED[LFS158]=y
MOOC[LFS158]=edX
INTERNET[LFS158]="$REQUIRED"
CPUFLAGS[LFS158]="svm|vmx"
#-------------------------------------------------------------------------------
OS[LFS158]="$ANYOS"
OS_NEEDS[LFS158]="$REMOTE_NEEDS"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS158]="LFS458"

#===============================================================================
# Extra requirements for LFS163
#===============================================================================
TITLE[LFS163]="Introduction to ONAP: Complete Network Automation"
WEBPAGE[LFS163]="$LFSTRAINING/introduction-to-onap-complete-network-automation"
INPERSON[LFS163]=n
VIRTUAL[LFS163]=n
SELFPACED[LFS163]=y
MOOC[LFS163]=edX
INTERNET[LFS163]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS163]="$ANYOS"
OS_NEEDS[LFS163]="$REMOTE_NEEDS"
#-------------------------------------------------------------------------------
PACKAGES[LFS163]="@common"

#===============================================================================
# Extra requirements for LFS164
#===============================================================================
TITLE[LFS164]="NFV Acceleration: An Introduction to OPNFV"
WEBPAGE[LFS164]="$LFSTRAINING/nfv-acceleration-an-introduction-to-opnfv"
INPERSON[LFS164]=n
VIRTUAL[LFS164]=n
SELFPACED[LFS164]=y
MOOC[LFS164]=edX
INTERNET[LFS164]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS164]="$ANYOS"
OS_NEEDS[LFS164]="$BROWSER"
#-------------------------------------------------------------------------------
PACKAGES[LFS164]="@common"

#===============================================================================
# Extra requirements for LFS165
#===============================================================================
TITLE[LFS165]="Introduction to Open Source Networking Technologies"
WEBPAGE[LFS165]="$LFSTRAINING/introduction-to-open-source-networking-technologies"
INPERSON[LFS165]=n
VIRTUAL[LFS165]=n
SELFPACED[LFS165]=y
MOOC[LFS165]=edX
INTERNET[LFS165]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS165]="$ANYOS"
OS_NEEDS[LFS165]="$BROWSER"
#-------------------------------------------------------------------------------
PACKAGES[LFS165]="@common"

#===============================================================================
# Extra requirements for LFS166
#===============================================================================
TITLE[LFS166]="Introduction to Magma: Cloud Native Wireless Networking"
WEBPAGE[LFS166]="$LFSTRAINING/introduction-to-magma-cloud-native-wireless-networking"
INPERSON[LFS166]=n
VIRTUAL[LFS166]=n
SELFPACED[LFS166]=y
MOOC[LFS166]=edX
INTERNET[LFS166]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS166]="$ANYOS"
OS_NEEDS[LFS166]="$BROWSER"

#===============================================================================
# Extra requirements for LFS170
#===============================================================================
TITLE[LFS170]="Blockchain: Understanding Its Uses and Implications"
WEBPAGE[LFS170]="$LFSTRAINING/blockchain-understanding-its-uses-and-implications"
INPERSON[LFS170]=n
VIRTUAL[LFS170]=n
SELFPACED[LFS170]=y
MOOC[LFS170]=edX
INTERNET[LFS170]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS170]="$ANYOS"
OS_NEEDS[LFS170]="$BROWSER"
#-------------------------------------------------------------------------------
PACKAGES[LFS170]="@common"

#===============================================================================
# Extra requirements for LFS171
#===============================================================================
TITLE[LFS171]="Introduction to Hyperledger Blockchain Technologies"
WEBPAGE[LFS171]="$LFSTRAINING/blockchain-for-business-an-introduction-to-hyperledger-technologies"
INPERSON[LFS171]=n
VIRTUAL[LFS171]=n
SELFPACED[LFS171]=y
MOOC[LFS171]=edX
INTERNET[LFS171]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS171]="$ANYOS"
OS_NEEDS[LFS171]="$BROWSER"

#===============================================================================
# Extra requirements for LFS176
#===============================================================================
TITLE[LFS176]="Hyperledger Besu Essentials: Creating a Private Blockchain Network"
WEBPAGE[LFS176]="$LFSTRAINING/hyperledger-besu-essentials-creating-a-private-blockchain-network-lfs176x"
INPERSON[LFS176]=n
VIRTUAL[LFS176]=n
SELFPACED[LFS176]=y
MOOC[LFS176]=edX
INTERNET[LFS176]="$REQUIRED"
#-------------------------------------------------------------------------------
RAM[LFS176]=8
DISK[LFS176]=750
PACKAGES[LFS176]="@java"
PACKAGES[Debian_LFS176]="libsodium23"
PACKAGES[Debian-9_LFS176]="-libsodium23"
PACKAGES[RHEL_LFS176]="libsodium"
PACKAGES[openSUSE_LFS176]="libsodium23"

#===============================================================================
# Extra requirements for LFS177
#===============================================================================
TITLE[LFS177]="FDC3: Interoperability for the Financial Desktop"
WEBPAGE[LFS177]="$LFSTRAINING/fdc3-interoperability-for-the-financial-desktop-lfs177x"
INPERSON[LFS177]=n
VIRTUAL[LFS177]=n
SELFPACED[LFS177]=y
MOOC[LFS177]=edX
INTERNET[LFS177]="$REQUIRED"

#===============================================================================
# Extra requirements for LFS201
#===============================================================================
TITLE[LFS201]="Essentials of Linux System Administration"
WEBPAGE[LFS201]="$LFSTRAINING/essentials-of-linux-system-administration"
INSTR_LED_CLASS[LFS201]="LFS301"
#-------------------------------------------------------------------------------
INPERSON[LFS201]=n
VIRTUAL[LFS201]=n
SELFPACED[LFS201]=y
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS201]="LFS301"

#===============================================================================
# Extra requirements for LFS211
#===============================================================================
TITLE[LFS211]="Linux Networking and Administration"
WEBPAGE[LFS211]="$LFSTRAINING/linux-networking-and-administration"
INPERSON[LFS211]=n
VIRTUAL[LFS211]=n
SELFPACED[LFS211]=y
INSTR_LED_CLASS[LFS211]="LFS311"
#-------------------------------------------------------------------------------
PACKAGES[LFS211]="@build @common @sysadm @trace ftp mutt nmap postfix vsftpd"
PACKAGES[Ubuntu_LFS211]="bsd-mailx dovecot-imapd dovecot-lmtpd dovecot-pop3d
	openssh-server"
RECOMMENDS[Ubuntu_LFS211]="zenmap"
RECOMMENDS[Ubuntu-20.04_LFS211]="-zenmap"
RECOMMENDS[Debian-999_LFS211]="-zenmap"
PACKAGES[RHEL_LFS211]="dovecot kernel-modules-extra mailx openssh-server"
PACKAGES[RHEL-7_LFS211]="-kernel-modules-extra"
PACKAGES[openSUSE_LFS211]="dovecot mailx openssh"
RECOMMENDS[openSUSE_LFS211]="zenmap"
RECOMMENDS[openSUSE-999_LFS211]="-zenmap"

#===============================================================================
# Extra requirements for LFS216
#===============================================================================
TITLE[LFS216]="Linux Security Fundamentals"
WEBPAGE[LFS216]="$LFSTRAINING/linux-security-fundamentals"
INPERSON[LFS216]=n
VIRTUAL[LFS216]=n
SELFPACED[LFS216]=y
INSTR_LED_CLASS[LFS216]="LFS416"
CPUS[LFS216]=8
BOGOMIPS[LFS216]=20000
RAM[LFS216]=8
DISK[LFS216]=40
INTERNET[LFS216]="$REQUIRED"
CPUFLAGS[LFS216]="svm|vmx"
CONFIGS[LFS216]="HAVE_KVM KSM"
VMOKAY[LFS216]="$RECOMMENDED"
enable_extras "LFS216"
VMS[LFS216]="CentOS7"
#-------------------------------------------------------------------------------
PACKAGES[LFS216]="@build @common @ebpf @virt"
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu_LFS216]="apache2-utils"
PACKAGES[RHEL_LFS216]="kernel-devel"
PACKAGES[openSUSE_LFS216]="[RHEL_LFS216]"

#===============================================================================
# Extra requirements for LFS241
#===============================================================================
TITLE[LFS241]="Monitoring Systems and Services with Prometheus"
WEBPAGE[LFS241]="$LFSTRAINING/monitoring-systems-and-services-with-prometheus-lfs241"
INPERSON[LFS241]=n
VIRTUAL[LFS241]=n
SELFPACED[LFS241]=y
INTERNET[LFS241]="$REQUIRED"
#-------------------------------------------------------------------------------
CPUS[LFS241]=2
RAM[LFS241]=4
DISK[LFS241]=50
DISTROS[LFS241]="Ubuntu-20.04"
#-------------------------------------------------------------------------------
PACKAGES[LFS241]="@common @docker"

#===============================================================================
# Extra requirements for LFS242
#===============================================================================
TITLE[LFS242]="Cloud Native Logging with Fluentd"
WEBPAGE[LFS242]="$LFSTRAINING/cloud-native-logging-with-fluentd-lfs242"
INPERSON[LFS242]=n
VIRTUAL[LFS242]=n
SELFPACED[LFS242]=y
INTERNET[LFS242]="$REQUIRED"
#-------------------------------------------------------------------------------
CPUS[LFS242]=2
RAM[LFS242]=2
DISK[LFS242]=30
DISTROS[LFS242]="Ubuntu-LTS"
VMOKAY[LFS242]="$RECOMMENDED"
#-------------------------------------------------------------------------------
PACKAGES[LFS242]="@common @docker"

#===============================================================================
# Extra requirements for LFS243
#===============================================================================
TITLE[LFS243]="Service Mesh Fundamentals"
WEBPAGE[LFS243]="$LFSTRAINING/service-mesh-fundamentals-lfs243"
INPERSON[LFS243]=n
VIRTUAL[LFS243]=n
SELFPACED[LFS243]=y
INTERNET[LFS243]="$REQUIRED"
#-------------------------------------------------------------------------------
CPUS[LFS243]=4
RAM[LFS243]=15
DISK[LFS243]=30
DISTROS[LFS243]="Ubuntu-20.04"
VMOKAY[LFS243]="$RECOMMENDED"
#-------------------------------------------------------------------------------

#===============================================================================
# Extra requirements for LFS244
#===============================================================================
TITLE[LFS244]="Managing Kubernetes Applications with Helm"
WEBPAGE[LFS244]="$LFSTRAINING/managing-kubernetes-applications-with-helm-lfs244"
INPERSON[LFS244]=n
VIRTUAL[LFS244]=n
SELFPACED[LFS244]=y
INTERNET[LFS244]="$REQUIRED"
#-------------------------------------------------------------------------------
CPUS[LFS244]=2
RAM[LFS244]=4
DISK[LFS244]=50
#-------------------------------------------------------------------------------
SUGGESTS[LFS244]="@common @docker"

#===============================================================================
# Extra requirements for LFS250
#===============================================================================
TITLE[LFS250]="Kubernetes and Cloud Native Essentials"
WEBPAGE[LFS250]="$LFSTRAINING/kubernetes-and-cloud-native-essentials-lfs250"
INPERSON[LFS250]=n
VIRTUAL[LFS250]=n
SELFPACED[LFS250]=y
#-------------------------------------------------------------------------------
OS[LFS250]="$ANYOS"
OS_NEEDS[LFS250]="$BROWSER"
#-------------------------------------------------------------------------------
INTERNET[LFS250]="$REQUIRED"

#===============================================================================
# Extra requirements for LFS253
#===============================================================================
TITLE[LFS253]="Containers Fundamentals"
WEBPAGE[LFS253]="$LFSTRAINING/containers-fundamentals"
INPERSON[LFS253]=n
VIRTUAL[LFS253]=n
SELFPACED[LFS253]=y
#-------------------------------------------------------------------------------
OS[LFS253]="$ANYOS"
OS_NEEDS[LFS253]="$REMOTE_NEEDS"
#-------------------------------------------------------------------------------
INTERNET[LFS253]="$REQUIRED"
DISTROS[LFS253]="${DISTROS[LFD]}"
PACKAGES[LFS253]="@docker"

#===============================================================================
# Extra requirements for LFS258
#===============================================================================
TITLE[LFS258]="Kubernetes Fundamentals"
WEBPAGE[LFS258]="$LFSTRAINING/kubernetes-fundamentals"
INSTR_LED_CLASS[LFS258]="LFS458"
INPERSON[LFS258]=n
VIRTUAL[LFS258]=n
SELFPACED[LFS258]=y
RAM[LFS258]=4
#-------------------------------------------------------------------------------
OS[LFS258]="$ANYOS"
OS_NEEDS[LFS258]="$REMOTE_NEEDS, Kubernetes CLI (kubectl)"
INTERNET[LFS258]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS258]="LFS158"

#===============================================================================
# Extra requirements for LFS260
#===============================================================================
TITLE[LFS260]="Kubernetes Security Essentials"
WEBPAGE[LFS260]="$LFSTRAINING/kubernetes-security-essentials-lfs260"
INSTR_LED_CLASS[LFS260]="LFS460"
INPERSON[LFS260]=n
VIRTUAL[LFS260]=n
SELFPACED[LFS260]=y
#-------------------------------------------------------------------------------
OS[LFS260]="$ANYOS"
OS_NEEDS[LFS260]="$REMOTE_NEEDS, Kubernetes CLI (kubectl)"
INTERNET[LFS260]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS260]="LFD259"

#===============================================================================
# Extra requirements for LFS261
#===============================================================================
TITLE[LFS261]="Implementing Continuous Delivery"
WEBPAGE[LFS261]="$LFSTRAINING/devops-and-sre-fundamentals-implementing-continuous-delivery-lfs261"
INPERSON[LFS261]=n
VIRTUAL[LFS261]=n
SELFPACED[LFS261]=y
INTERNET[LFS261]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS261]="$ANYOS"
OS_NEEDS[LFS261]="$REMOTE_NEEDS, Google Cloud account (free tier)"

#===============================================================================
# Extra requirements for LFS263
#===============================================================================
TITLE[LFS263]="ONAP Fundamentals"
WEBPAGE[LFS263]="$LFSTRAINING/onap-fundamentals"
INPERSON[LFS263]=n
VIRTUAL[LFS263]=n
SELFPACED[LFS263]=y
INTERNET[LFS263]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS263]="$ANYOS"
OS_NEEDS[LFS263]="$GCP"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS263]="LFS163"

#===============================================================================
# Extra requirements for LFS264
#===============================================================================
TITLE[LFS264]="OPNFV Fundamentals"
WEBPAGE[LFS264]="$LFSTRAINING/opnfv-fundamentals"
INPERSON[LFS264]=n
VIRTUAL[LFS264]=n
SELFPACED[LFS264]=y
INTERNET[LFS264]="$REQUIRED"
#-------------------------------------------------------------------------------
OS[LFS264]="$ANYOS"
OS_NEEDS[LFS264]="$GCP"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS264]="LFS164"

#===============================================================================
# Extra requirements for LFS266
#===============================================================================
TITLE[LFS266]="DevOps for Network Engineers"
WEBPAGE[LFS266]="$LFSTRAINING/devops-for-network-engineers-lfs266"
INPERSON[LFS266]=n
VIRTUAL[LFS266]=n
SELFPACED[LFS266]=y
INTERNET[LFS266]="$REQUIRED"
VMOKAY[LFS266]="$REQUIRED"
#-------------------------------------------------------------------------------
DISTROS[LFS266]="Ubuntu-20.04"

#===============================================================================
# Extra requirements for LFS267
#===============================================================================
TITLE[LFS267]="Jenkins Essentials"
WEBPAGE[LFS267]="$LFSTRAINING/jenkins-essentials-lfs267"
INPERSON[LFS267]=n
VIRTUAL[LFS267]=n
SELFPACED[LFS267]=y
INTERNET[LFS267]="$REQUIRED"
VMOKAY[LFS267]="$VMNOTOKAY"
#-------------------------------------------------------------------------------
OS[LFS267]="$ANYOS"
OS_NEEDS[LFS267]="$VAGRANTVB"
RAM[LFS267]="16"
DISK[LFS267]="20"

#===============================================================================
# Extra requirements for LFS268
#===============================================================================
TITLE[LFS268]="CI/CD with Jenkins X"
WEBPAGE[LFS268]="$LFSTRAINING/ci-cd-with-jenkins-x-lfs268"
INPERSON[LFS268]=n
VIRTUAL[LFS268]=n
SELFPACED[LFS268]=y
CPUS[LFS268]=1
PREFER_CPUS[LFS268]=2
RAM[LFS268]=8
INTERNET[LFS268]="$REQUIRED"
VMOKAY[LFS268]="$ACCEPTABLE"
#-------------------------------------------------------------------------------
OS[LFS268]="$ANYOS"
OS_NEEDS[LFS268]="$FREEGCP"

#===============================================================================
# Extra requirements for LFS269
#===============================================================================
TITLE[LFS269]="GitOps: Continuous Delivery on Kubernetes with Flux"
WEBPAGE[LFS269]="$LFSTRAINING/gitops-continuous-delivery-on-kubernetes-with-flux-lfs269"
INPERSON[LFS269]=n
VIRTUAL[LFS269]=n
SELFPACED[LFS269]=y
CPUS[LFS269]=2
PREFER_CPUS[LFS269]=4
RAM[LFS269]=2
INTERNET[LFS269]="$REQUIRED"
VMOKAY[LFS269]="$ACCEPTABLE"
#-------------------------------------------------------------------------------
PACKAGES[LFS269]="git curl"

#===============================================================================
# Extra requirements for LFS272
#===============================================================================
TITLE[LFS272]="Hyperledger Fabric Administration"
WEBPAGE[LFS272]="$LFSTRAINING/hyperledger-fabric-administration-lfs272"
INPERSON[LFS272]=n
VIRTUAL[LFS272]=n
SELFPACED[LFS272]=y
PREREQ[LFS272]="LFS171"
INTERNET[LFS272]="$REQUIRED"
VMOKAY[LFS272]="$RECOMMENDED"
#-------------------------------------------------------------------------------
RAM[LFS272]=4
DISK[LFS272]=30
CPUFLAGS[LFS272]="svm|vmx"

#===============================================================================
# Extra requirements for LFS300
#===============================================================================
TITLE[LFS300]="Fundamentals of Linux"
WEBPAGE[LFS300]="$LFSTRAINING/fundamentals-of-linux"
#-------------------------------------------------------------------------------
PACKAGES[LFS300]="@common qpdf"

#===============================================================================
# Extra requirements for LFS301
#===============================================================================
TITLE[LFS301]="Linux for System Administrations"
WEBPAGE[LFS301]="$LFSTRAINING/linux-for-system-administrators"
SELFPACED_CLASS[LFS301]="LFS201"
#-------------------------------------------------------------------------------
PACKAGES[LFS301]="@build @common @docker @sysadm @trace @virt btrfs-progs
	cryptsetup lvm2 quota xfsprogs"
PACKAGES[RHEL-7_LFS301]="-cryptsetup"
PACKAGES[RHEL-8_LFS301]="-btrfs-progs"
PACKAGES[openSUSE_LFS301]="-btrfs-progs btrfsprogs"

#===============================================================================
# Extra requirements for LFS311
#===============================================================================
TITLE[LFS311]="Linux for System Engineers"
WEBPAGE[LFS311]="$LFSTRAINING/linux-for-system-engineers"
SELFPACED_CLASS[LFS311]="LFS211"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS311]="LFS211"

#===============================================================================
# Extra requirements for LFS416
#===============================================================================
TITLE[LFS416]="Linux Security"
WEBPAGE[LFS416]="$LFSTRAINING/linux-security"
SELFPACED_CLASS[LFS416]="LFS216"
CPUS[LFS416]=4
BOGOMIPS[LFS416]=20000
RAM[LFS416]=8
DISK[LFS416]=40
INTERNET[LFS416]="$REQUIRED"
CPUFLAGS[LFS416]="svm|vmx"
CONFIGS[LFS416]="HAVE_KVM KSM"
VMOKAY[LFS416]="$RECOMMENDED"
enable_extras "LFS416"
VMS[LFS416]="CentOS7"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS416]="LFS216"

#===============================================================================
# Extra requirements for LFS426
#===============================================================================
TITLE[LFS426]="Linux Performance Tuning"
WEBPAGE[LFS426]="$LFSTRAINING/linux-performance-tuning"
#ARCH[LFS426]=x86_64
CPUS[LFS426]=2
PREFER_CPUS[LFS426]=4
BOGOMIPS[LFS426]=20000
RAM[LFS426]=2
DISK[LFS426]=20
NATIVELINUX[LFS426]="$RECOMMENDED"
VMOKAY[LFS426]="$DISCOURAGED"
#DISTRO_ARCH[LFS426]=x86_64
INTERNET[LFS426]="$REQUIRED"
#-------------------------------------------------------------------------------
PACKAGES[LFS426]="@stress @sysadm @trace @virt blktrace blktrace crash
	fio hdparm lynx systemtap valgrind"
PACKAGES[Debian_LFS426]="cpufrequtils iozone3 libaio-dev libblas-dev libncurses5-dev
	libnuma-dev nfs-kernel-server zlib1g-dev"
PACKAGES[Debian-10_LFS426]="lmbench -libncurses5-dev libncurses-dev"
PACKAGES[Ubuntu_LFS426]="[Debian_LFS426] lmbench nfs-kernel-server oprofile"
PACKAGES[Ubuntu-20.04_LFS426]="-libncurses5-dev libncurses-dev"
PACKAGES[RHEL_LFS426]="blas-devel kernel-devel libaio-devel libhugetlbfs-utils
	ncurses-devel numactl-libs perl-Time-HiRes zlib-devel"
PACKAGES[RHEL-7_LFS426]="oprofile"
PACKAGES[RHEL-8_LFS426]="-"
PACKAGES[Fedora_LFS426]="-libhugetlbfs-utils"
PACKAGES[openSUSE_LFS426]="blas-devel iozone kernel-devel libaio-devel ncurses-devel
	nfs-kernel-server oprofile zlib-devel zlib-devel-static"

#===============================================================================
# Extra requirements for LFS458
#===============================================================================
TITLE[LFS458]="Kubernetes Administration"
WEBPAGE[LFS458]="$LFSTRAINING/kubernetes-administration"
SELFPACED_CLASS[LFS458]="LFS258"
RAM[LFS458]=4
#-------------------------------------------------------------------------------
# shellcheck disable=SC2034
OS[LFS458]="$ANYOS"
OS_NEEDS[LFS458]="$REMOTE_NEEDS, Kubernetes CLI (kubectl)"
INTERNET[LFS458]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS458]="LFS258"

#===============================================================================
# Extra requirements for LFS460
#===============================================================================
TITLE[LFS460]="Kubernetes Security Fundamentals"
WEBPAGE[LFS460]="$LFSTRAINING/kubernetes-security-fundamentals-lfs460"
SELFPACED_CLASS[LFS460]="LFS260"
#-------------------------------------------------------------------------------
OS[LFS460]="$ANYOS"
OS_NEEDS[LFS460]="$REMOTE_NEEDS, Kubernetes CLI (kubectl)"
INTERNET[LFS460]="$REQUIRED"
#-------------------------------------------------------------------------------
COPYPACKAGES[LFS460]="LFD259"

#===============================================================================
# Extra requirements for LFS462
#===============================================================================
TITLE[LFS462]="Open Source Virtualization"
WEBPAGE[LFS462]="$LFSTRAINING/open-source-virtualization"
CPUS[LFS462]=2
PREFER_CPUS[LFS462]=4
BOGOMIPS[LFS462]=10000
RAM[LFS462]=4
DISK[LFS462]=40
CPUFLAGS[LFS462]="svm|vmx"
CONFIGS[LFS462]="HAVE_KVM KSM"
NATIVELINUX[LFS462]="$REQUIRED"
VMOKAY[LFS462]="This course can't be run on a VM"
#-------------------------------------------------------------------------------
PACKAGES[LFS462]="@build @common @virt firewalld"
#-------------------------------------------------------------------------------
PACKAGES[Ubuntu_LFS462]="g++"
PACKAGES[RHEL_LFS462]="kernel-devel"
#PACKAGES[RHEL-7_LFS462]="-firewalld"
PACKAGES[openSUSE_LFS462]="[RHEL_LFS462]"

#===============================================================================
#=== End of LFS Course Definitions =============================================
#===============================================================================


#===============================================================================
# Extra requirements for LFW111
#===============================================================================
TITLE[LFW111]="Introduction to Node.js"
WEBPAGE[LFW111]="$LFSTRAINING/introduction-to-nodejs-lfw111"
INPERSON[LFW111]=n
VIRTUAL[LFW111]=n
SELFPACED[LFW111]=y
MOOC[LFW111]=edX
#-------------------------------------------------------------------------------
PREFER_CPUS[LFW111]=4
RAM[LFW111]=2
INTERNET[LFW111]="$REQUIRED"
#OS[LFW111]="$ANYOS"
#OS_NEEDS[LFW111]="$REMOTE_NEEDS"
#-------------------------------------------------------------------------------
PACKAGES[LFW111]="@build bash ca-certificates curl openssl python2"
PACKAGES[Debian_LFW111]="linux-headers-amd64 ncurses-bin"
PACKAGES[Debian-9_LFW111]="-python2 python"
PACKAGES[Ubuntu_LFW111]="linux-headers-generic ncurses-bin"
PACKAGES[Ubuntu-18.04_LFW111]="-python2 python"
PACKAGES[Ubuntu-20.04_LFW111]="-"
PACKAGES[CentOS_LFW111]="kernel-devel ncurses"
PACKAGES[CentOS-7_LFW111]="-python2"
PACKAGES[Fedora_LFW111]="[CentOS_LFW111] -python2"
PACKAGES[openSUSE_LFW111]="[CentOS_LFW111]"
PACKAGES[openSUSE-15.2_LFW111]="-ncurses -python2 python"
PACKAGES[openSUSE-15.3_LFW111]="-ncurses -python2 python"

#===============================================================================
# Extra requirements for LFW211
#===============================================================================
TITLE[LFW211]="Node.js Application Development"
WEBPAGE[LFW211]="$LFSTRAINING/nodejs-application-development-lfw211"
INPERSON[LFW211]=n
VIRTUAL[LFW211]=n
SELFPACED[LFW211]=y
#-------------------------------------------------------------------------------
OS[LFW211]="$ANYOS"
OS_NEEDS[LFW211]="$REMOTE_NEEDS"
INTERNET[LFW211]="$REQUIRED"

#===============================================================================
# Extra requirements for LFW212
#===============================================================================
TITLE[LFW212]="Node.js Services Development"
WEBPAGE[LFW212]="$LFSTRAINING/node-js-services-development-lfw212"
INPERSON[LFW212]=n
VIRTUAL[LFW212]=n
SELFPACED[LFW212]=y
#-------------------------------------------------------------------------------
OS[LFW212]="$ANYOS"
OS_NEEDS[LFW212]="$REMOTE_NEEDS"
INTERNET[LFW212]="$REQUIRED"

#==============================================================================
list_grep() {
    local REGEX
    #REGEX=$(sed -e 's/\+/\\+/g' <<<"$1"); shift
    REGEX="${1//\+/\\+}"; shift
    # shellcheck disable=SC2086
    debug 3 "list_grep REGEX=$REGEX => "$*
    # shellcheck disable=SC2001
    sed 's/ /\n/g' <<< "$@" | grep -E "$REGEX" | sort -u
}

#===============================================================================
list_sort() {
    # shellcheck disable=SC2001
    sed 's/ /\n/g' <<< "$@" | sort -u
}

#===============================================================================
value() {
    local VAR=$1
    local ACTIVITY=${2:-}
    local LIST
    debug 2 "  value: VAR=$VAR ACTIVITY=$ACTIVITY"
    [[ -n $VAR && -n $ACTIVITY ]] || error "value: bad arguments: VAR=$VAR ACTIVITY=$ACTIVITY"
    # shellcheck disable=SC2016
    LIST='${'$VAR'['$ACTIVITY']:-} ${'$VAR'['${ACTIVITY:0:3}']:-} ${'$VAR':-}'

    for V in $LIST; do
        debug 3 "    value: VAR=$VAR ACTIVITY=$ACTIVITY V=$V"
        V=$(eval echo "$V")
        if [[ -n $V ]] ; then
            echo "$V"
            return 0
        fi
    done
}

#===============================================================================
strip_versions() {
    local ACTIVITY
    for ACTIVITY in "$@" ; do
        echo "${ACTIVITY%%=*}"
    done
}

#===============================================================================
for_each_activity() {
    local CODE=$1; shift
    local ACTIVITIES ACTIVITY
    # shellcheck disable=SC2046
    ACTIVITIES=$(list_sort $(strip_versions "$@"))
    # shellcheck disable=SC2086
    debug 1 "for_each_activity: CODE=$CODE ACTIVITIES="$ACTIVITIES
    for ACTIVITY in $ACTIVITIES ; do
        debug 2 "  for_each_activity: eval $CODE $ACTIVITY"
        eval "$CODE $ACTIVITY"
    done
}

#===============================================================================
supported_activity() {
    local ACTIVITY=$1
    [[ -n ${TITLE[$ACTIVITY]} ]] || warn "Unsupported activity: $ACTIVITY"
}

#===============================================================================
check_activity() {
    local ACTIVITY=$1
    local DESC=${TITLE[$ACTIVITY]}
    debug 1 "check_activity: ACTIVITY=$ACTIVITY"

    if [[ -z $DESC ]] ; then
        if DESC=$(get_var TITLE "$ACTIVITY") && [[ -n $DESC ]] ; then
            debug 2 "  check_activity: Custom $ACTIVITY"
        elif [[ -n ${ACTIVITY_ALIASES[$ACTIVITY]} ]] ; then
            debug 2 "  check_activity: Alias $ACTIVITY"
            ACTIVITY=${ACTIVITY_ALIASES[$ACTIVITY]}
            DESC=${TITLE[$ACTIVITY]}
        fi
        debug 2 "  check_activity: ACTIVITY=$ACTIVITY DESC=$DESC"
    fi

    if [[ -n $DESC ]] ; then
        highlight "Checking that this computer is suitable for $ACTIVITY: $DESC"
    else
        warn "Unknown \"$ACTIVITY\"; checking defaults requirements instead"
    fi

    local ANNOUNCE
    if ANNOUNCE=$(get_var ANNOUNCEMENT "$ACTIVITY") && [[ -n $ANNOUNCE ]] ; then
        notice "$ANNOUNCE"
    fi
}

#===============================================================================
try_activity() {
    local ACTIVITY=$1 NEWACTIVITY=$2
    [[ -n ${TITLE[$NEWACTIVITY]} ]] || return 1
    if warn_wait "I think you meant $NEWACTIVITY (not $ACTIVITY)" ; then
        echo "$NEWACTIVITY"
    else
        echo "$ACTIVITY"
    fi
}

#===============================================================================
spellcheck_activity() {
    local ACTIVITY=$1
    local ACTIVITIES
    [[ -n $ACTIVITY ]] || return 0
    if [[ -n ${TITLE[$ACTIVITY]} ]] ; then
        echo "$ACTIVITY"
    elif ACTIVITIES=$(get_var COURSES "$ACTIVITY") && [[ -n $ACTIVITIES ]] ; then
        echo "$ACTIVITIES"
    else
        try_activity "$ACTIVITY" "${ACTIVITY/LFD/LFS}" \
            || try_activity "$ACTIVITY" "${ACTIVITY/LFS/LFD}" \
            || echo "$ACTIVITY"
    fi
}

#===============================================================================
find_activity() {
    local ACTIVITY=$1

    if [[ -n $ACTIVITY && -n ${ACTIVITY_ALIASES[$ACTIVITY]:-} ]] ; then
        notice "$ACTIVITY is an alias for ${ACTIVITY_ALIASES[$ACTIVITY]}"
        ACTIVITY=${ACTIVITY_ALIASES[$ACTIVITY]}
    fi
    spellcheck_activity "$ACTIVITY"
}

#===============================================================================
# List available activities
list_activities() {
    echo "Available (${#TITLE[@]}) options:"
    for D in ${!TITLE[*]}; do
        echo "  $D - ${TITLE[$D]}"
    done | sort
    exit 0
}
[[ -z $LIST_ACTIVITIES ]] || list_activities

#===============================================================================
# Try package list for all activities
try_all_activities() {
    local A
    # shellcheck disable=SC2086
    for A in $(list_sort ${!TITLE[*]}); do
        divider "$A"
        NO_PASS=y $CMDNAME \
                ${NOCM:+--no-course-files} \
                ${NOEXTRAS:+--no-extras} \
                ${NOINSTALL:+--no-install} \
                ${NORECOMMENDS:+--no-recommends} \
                ${NOSUGGESTS:+--no-suggests} \
                ${NOVM:+--no-vm} \
                "$A"
    done
    exit 0
}
[[ -z $TRY_ALL_ACTIVITIES ]] || try_all_activities

#===============================================================================
# shellcheck disable=SC2086
debug 1 "before: ACTIVITIES="$COURSE
# shellcheck disable=SC2005,SC2046,SC2086
[[ -z $ALL_LFD ]] || COURSE=$(echo $(list_grep LFD ${!TITLE[*]}))
# shellcheck disable=SC2005,SC2046,SC2086
[[ -z $ALL_LFS ]] || COURSE=$(echo $(list_grep LFS ${!TITLE[*]}))
# shellcheck disable=SC2005,SC2046,SC2086
[[ -z $ALL_ACTIVITIES ]] || COURSE=$(echo $(list_sort ${!TITLE[*]}))
# shellcheck disable=SC2086
debug 1 "after: ACTIVITIES="$COURSE

#===============================================================================
ORIG_COURSE=$COURSE
# shellcheck disable=SC2046,SC2086
COURSE=$(list_sort $(for_each_activity find_activity $COURSE))
# shellcheck disable=SC2086
debug 1 "main: Initial classes="$COURSE


declare -A DISTS

SHOWLOOKUPS=${SHOWLOOKUPS:-}
LOOKUPS=
#===============================================================================
show_lookup() {
    if [[ -n $SHOWLOOKUPS ]] ; then
        # shellcheck disable=SC2086
        echo -e "${CYAN}LOOKUP${BACK}: $*" >&2
    fi
}

#===============================================================================
list_distro_names() {
    local DISTS D
    DISTS=$(distrib_list)
    for D in $DISTS ; do
       if [[ -n ${DISTRO_NAMES[$D]:-} ]] ; then
           echo "${DISTRO_NAMES[$D]}"
       else
           echo "$D"
       fi
    done
}

#===============================================================================
# Make sure we're using a defined distribution key
distrib_ver() {
    local DID=$1 DREL=$2
    local AVAIL_INDEXES AVAIL_RELS DVER
    debug 1 "distrib_ver: DID=$DID DREL=$DREL"
    AVAIL_INDEXES=$(for D in "${!PACKAGES[@]}" "${!RECOMMENDS[@]}" "${!SUGGESTS[@]}"; do
        echo "$D"
    done | grep "$DID" | sort -u)
    # shellcheck disable=SC2086
    debug 2 "  distrib_ver: Available package indexes for $DID:" $AVAIL_INDEXES
    AVAIL_RELS=$(for R in $AVAIL_INDEXES; do
        local R=${R#*-}
        echo "${R%_*}"
    done | grep -v "^$DID" | sort -n -u)
    # shellcheck disable=SC2086
    debug 2 "  distrib_ver: Available distro releases for $DID:" $AVAIL_RELS
    DVER=1
    for R in $AVAIL_RELS ; do
        if version_greater_equal "$R" "$DREL" ; then
            DVER="$R"
            break
        fi
    done
    debug 1 "  distrib_ver: We're going to use $DID-$DVER (was $DID-$DREL)"
    echo "$DVER"
}

#===============================================================================
# Do a lookup in DB of KEY
lookup() {
    local DB=$1
    local KEY=${2%_}
    debug 1 "  lookup: DB=$DB KEY=$KEY"
    if [[ -n $KEY ]] ; then
        local DATA
        DATA=$(eval "echo \${${DB}[$KEY]:-}")
        if [[ $DB == PACKAGES ]] ; then
            show_lookup "  $KEY: $DATA"
            LOOKUPS+="$KEY "
        fi
        if [[ -n $DATA ]] ; then
            debug 2 "    lookup: hit ${DB}[$KEY] -> $DATA"
            echo "$DATA"
            return 0
        fi
    fi
    return 1
}

#===============================================================================
# Do a lookup in DB for DID[-DVER] and if not found, consult FALLBACK distros
lookup_fallback() {
    local DB=$1
    local DID=$2
    local DVER=$3
    local NAME=$4
    debug 2 "  lookup_fallback: DB=$DB DID=$DID DVER=$DVER NAME=$NAME"
    DID+=${DVER:+-$DVER}
    local KEY
    if [[ -n $DID && -n ${FALLBACK[${DID}]:-} ]] ; then
        debug 2 "    lookup_fallback: $DID => ${FALLBACK[${DID}]}"
        for KEY in $DID ${FALLBACK[${DID}]} ; do
            KEY+=${NAME:+_$NAME}
            show_lookup "$DID -> $KEY"
            if lookup "$DB" "$KEY" ; then
                return 0
            fi
        done
    fi
}

#===============================================================================
# Do a lookup in DB for NAME, DID_NAME, DID-DVER_NAME
get_db() {
    local DB=$1
    local DID=$2
    local DVER=$3
    local NAME=${4:-}
    local RESULT
    debug 1 "get_db: DB=$DB DID=$DID DVER=$DVER NAME=$NAME"

#    if [[ $DB = PACKAGES && ! $NAME =~ ^@ ]] ; then
#        notice "get_db: DB=$DB DID=$DID DVER=$DVER NAME=$NAME"
#    fi

    # Example: Ubuntu-18.04 Ubuntu-18.04_LFD420 Ubuntu_LFD420
    RESULT="$(lookup "$DB" "$NAME")"
    RESULT+=" $(lookup "$DB" "${DID}_$NAME")"
    RESULT+=" $(lookup "$DB" "$DID-${DVER}_$NAME")"
    RESULT+=" $(lookup_fallback "$DB" "$DID" '' "$NAME")"
    RESULT+=" $(lookup_fallback "$DB" "$DID" "$DVER" "$NAME")"
    # shellcheck disable=SC2086
    debug 3 "  get_db: RESULT="$RESULT
    # shellcheck disable=SC2086
    echo $RESULT
}

#===============================================================================
# Recursively expand macros in package list
pkg_list_expand() {
    local DB=$1; shift
    local DID=$1; shift
    local DREL=$1; shift
    local KEY PKGS
    # shellcheck disable=SC2086
    debug 3 "  pkg_list_expand: DB=$DB DID=$DID DREL=$DREL PLIST="$*

    for KEY in "$@" ; do
        case $KEY in
            @*) PKGS=$(get_db "$DB" "$DID" "$DREL" "$KEY")
                # shellcheck disable=SC2086
                pkg_list_expand "$DB" "$DID" "$DREL" $PKGS ;;
            [*) PKGS=$(eval "echo \${$DB$KEY:-}") #]
                debug 3 "    pkg_list_expand: lookup macro $DB$KEY -> $PKGS"
                [[ $KEY != "$PKGS" ]] || error "Recursive package list: $KEY"
                # shellcheck disable=SC2086
                pkg_list_expand "$DB" "$DID" "$DREL" $PKGS ;;
            *) echo "$KEY" ;;
        esac
    done
}

#===============================================================================
# Handle removing packages from the list: foo -foo
pkg_list_contract() {
    local BEFORE AFTER
    BEFORE=$(list_sort "$@")
    AFTER=$BEFORE
    # shellcheck disable=SC2086
    debug 3 "  pkg_list_contract BEFORE="$BEFORE
    for PKG in $BEFORE; do
        if [[ $PKG == -* ]] ; then
            PKG=${PKG//+/\\+}
            AFTER=$(for P in $AFTER; do
                echo "$P"
            done | grep -E -v "^-?${PKG#-}$")
        fi
    done
    # shellcheck disable=SC2086
    debug 3 "  pkg_list_contract: AFTER="$AFTER
    # shellcheck disable=SC2086
    list_sort $AFTER
}

#===============================================================================
# Check package list for obvious problems
pkg_list_check() {
    for PKG in "${!PACKAGES[@]}" "${!RECOMMENDS[@]}" "${!SUGGESTS[@]}"; do
        # shellcheck disable=SC2188
        case "$PKG" in
            @*|*_@*) >/dev/null;;
            *@*) fail "'$PKG' is likely invalid. I think you meant '${PKG/@/_@}'";;
            *-LF*) fail "'$PKG' is likely invalid. I think you meant '${PKG/-LF/_LF}'";;
            LF*_*) fail "'$PKG' is likely invalid. I think you meant '$(sed -re 's/(LF....)_([^_]+)/\2_\1/')'";;
            *) >/dev/null;;
        esac
    done
}

#===============================================================================
# Add packages to the list
pkg_list_lookup() {
    local TYPE=$1
    local DID=$2
    local DVER=$3
    local NAME=$4
    local LIST

    LIST=$(get_db "$TYPE" "$DID" "$DVER" "$NAME")
    # shellcheck disable=SC2086
    debug 2 "  pkg_list_lookup: $TYPE DID=$DID DVER=$DVER NAME=$NAME LIST="$LIST
    echo "$LIST"
}

#===============================================================================
# Build package list
# TODO: Needs to be tested more with other distros
package_list() {
    local DID=$1
    local DREL=$2
    local ACTIVITY=$3
    local DVER LIST PLIST RLIST='' SLIST=''
    debug 1 "package_list: DID=$DID DREL=$DREL ACTIVITY=$ACTIVITY"

    DVER=$(distrib_ver "$DID" "$DREL")
    show_lookup "package list for $ACTIVITY: $DID-$DVER ($DREL)"

    pkg_list_check

    if [[ -n ${COPYPACKAGES[$ACTIVITY]:-} ]] ; then
        debug 1 "  package_list: COPYPACKAGES $ACTIVITY -> ${COPYPACKAGES[$ACTIVITY]}"
        ACTIVITY=${COPYPACKAGES[$ACTIVITY]}
    fi

    #---------------------------------------------------------------------------
    # Build initial lists
    PLIST=$(pkg_list_lookup PACKAGES "$DID" "$DVER" "$ACTIVITY")
    # shellcheck disable=SC2086
    debug 2 "  package_list:(initial) PACKAGES PLIST="$PLIST
    if [[ -z $NORECOMMENDS ]] ; then
        # shellcheck disable=SC2046,SC2086
        RLIST=$(list_sort $(pkg_list_lookup RECOMMENDS "$DID" "$DVER" "$ACTIVITY") $PLIST)
        # shellcheck disable=SC2086
        debug 2 "  package_list:(initial) RECOMMENDS RLIST="$RLIST
    fi
    if [[ -z $NOSUGGESTS ]] ; then
        # shellcheck disable=SC2046,SC2086
        SLIST=$(list_sort $(pkg_list_lookup SUGGESTS "$DID" "$DVER" "$ACTIVITY") $PLIST $RLIST)
        # shellcheck disable=SC2086
        debug 2 "  package_list:(initial) SUGGESTS SLIST="$SLIST
    fi

    #---------------------------------------------------------------------------
    # Expand lists
    # shellcheck disable=SC2046,SC2086
    PLIST=$(pkg_list_expand PACKAGES "$DID" "$DVER" $PLIST)
    # shellcheck disable=SC2086
    debug 1 "  package_list:(expanded) PACKAGES PLIST="$PLIST
    if [[ -z $NORECOMMENDS ]] ; then
        # shellcheck disable=SC2046,SC2086
        RLIST=$(pkg_list_expand RECOMMENDS "$DID" "$DVER" $RLIST)
        # shellcheck disable=SC2086
        debug 1 "  package_list:(expanded) RECOMMENDS RLIST="$RLIST
    fi
    if [[ -z $NOSUGGESTS ]] ; then
        # shellcheck disable=SC2046,SC2086
        SLIST=$(pkg_list_expand SUGGESTS "$DID" "$DVER" $SLIST)
        # shellcheck disable=SC2086
        debug 1 "  package_list:(expanded) SUGGESTS SLIST="$SLIST
    fi

    #---------------------------------------------------------------------------
    # Contract list
    if [[ -z $NOCONTRACT ]] ; then
        # shellcheck disable=SC2086
        LIST=$(pkg_list_contract ${PLIST:-} ${RLIST:-} ${SLIST:-})
    else
        LIST="${PLIST:-} ${RLIST:-} ${SLIST:-}"
    fi
    # shellcheck disable=SC2086
    debug 1 "  package_list: Final packages for $DID-${DVER}_$ACTIVITY:" $LIST
    echo "$LIST"

    if [[ -n $SHOWLOOKUPS ]] ; then
    show_lookup "package list for: $DID-$DVER ($DREL)"
    fi
}

#===============================================================================
diff_distro() {
    local CLASS DIST1 DIST2 D V P1 P2 OUTPUT
    IFS=, read -r DIST1 DIST2 <<<"$DIFF_DIST"

    for CLASS in $COURSE; do
        IFS=- read -r D V <<<"$DIST1"
        P1=$( package_list "$D" "$V" "$CLASS")
        IFS=- read -r D V <<<"$DIST2"
        P2=$( package_list "$D" "$V" "$CLASS")
        OUTPUT="$(diff -u <(echo "$P1") <(echo "$P2"))"
        if [[ -n $OUTPUT ]] ; then
            ( echo "Packages:$CLASS Distro1=$DIST1 Distro2=$DIST2"
            echo "$OUTPUT" ) | less
        fi
    done
}

#===============================================================================
# Check that activity webpages are valid
check_webpage() {
    local ACTIVITIES A
    ACTIVITIES=$(strip_versions "$@")
    # shellcheck disable=SC2086
    [[ -n $ACTIVITIES ]] || ACTIVITIES=$(list_sort ${!TITLE[*]})
    # shellcheck disable=SC2086
    debug 1 "check_webpage: ACTIVITIES="$ACTIVITIES

    # shellcheck disable=SC2086
    for A in $ACTIVITIES; do
        supported_activity "$A"

        if get "${WEBPAGE[$A]}" >/dev/null ; then
            [[ -n $VERBOSE ]] || progress '@'
        else
            warn "Got a 404: WEBPAGE for $A: ${WEBPAGE[$A]}"
            [[ -n $VERBOSE ]] || progress 'X'
        fi
    done
}

CKCACHE="$CMCACHE"

#===============================================================================
# Check Packages
check_packages() {
    local ACTIVITIES DISTS D DIST P
    ACTIVITIES=$(strip_versions "$@")
    local SEARCH="./scripts/pkgsearch"
    if [[ ! -x $SEARCH ]] ; then
        error "$SEARCH not found"
    fi
    # shellcheck disable=SC2086
    [[ -n $ACTIVITIES ]] || ACTIVITIES=$(list_sort ${!TITLE[*]})
    # shellcheck disable=SC2086
    debug 1 "check_packages: ACTIVITIES="$ACTIVITIES

    mkdir -p "$CKCACHE"
    #[[ -z $NOCACHE ]] || $SEARCH --dropcache

    if [[ -z $DIST_LIST ]] ; then
        DISTS=$(distrib_list)
    else
        DISTS=$DIST_LIST
    fi
    # shellcheck disable=SC2086
    debug 1 "  check_packages: DISTS="$DISTS
    local A
    for A in $ACTIVITIES; do
        local CHECKED="$CKCACHE/$A-checked" CP=""
        if [[ -z $NOCACHE && -e $CHECKED ]] ; then
            verbose "Already checked $A"
            [[ -n $VERBOSE ]] || cat "$CHECKED"
            continue
        fi
        supported_activity "$A"

        CP="$A "
        [[ -n $VERBOSE ]] || progress "$CP"

        check_webpage "$A"

        for DIST in $DISTS; do
            CP="$CP."
            [[ -n $VERBOSE ]] || progress '.'
            # shellcheck disable=SC2086
            P=$(package_list ${DIST/-/ } $A)
            if [[ -n $P ]] ; then
                # shellcheck disable=SC2086
                debug 2 "    check_packages: P="$P
                local OPTS='' OUTPUT
                [[ -n $VERBOSE ]] || OPTS="--quiet --progress"
                # shellcheck disable=SC2086
                debug 2 "    check_packages: $SEARCH $OPTS -df $DIST "$P
                # shellcheck disable=SC2086
                OUTPUT=$($SEARCH $OPTS -df "$DIST" $P)
                if [[ -n $OUTPUT ]] ; then
                    [[ -n $VERBOSE ]] || echo
                    notice "Checking $DIST for $A..."
                    echo "$OUTPUT"
                    CHECKED=""
                fi
            fi
        done

        [[ -n $VERBOSE ]] || progress "\n"
        if [[ -n $CHECKED ]] ; then
            echo "$CP" > "$CHECKED"
        fi
    done
    [[ -n $VERBOSE ]] || echo
}

#===============================================================================
# List Packages
list_packages() {
    local ACTIVITIES=$1
    local DISTS D DIST PL P

    DISTS=$(distrib_list)
    # shellcheck disable=SC2086
    debug 1 "list_packages: ACTIVITIES=$ACTIVITIES PKGS=$PKGS DISTS="$DISTS

    if [[ -n $ACTIVITIES ]] ; then
        supported_activity "$ACTIVITIES"
    else
        # shellcheck disable=SC2086
        ACTIVITIES=$(list_sort ${!TITLE[*]})
    fi
    for D in $ACTIVITIES; do
        notice "Listing packages for $D..."
        for DIST in $DISTS; do
            # shellcheck disable=SC2086
            PL=$(package_list ${DIST/-/ } $D)
            # shellcheck disable=SC2086
            debug 2 PL1=$PL
            # shellcheck disable=SC2086
            [[ -z $PKGS ]] || PL=$(list_grep "^$PKGS$" $PL)
            # shellcheck disable=SC2086
            debug 2 PL2=$PL
            for P in $PL ; do
                echo -e "$DIST\t$P"
            done
        done
    done
}

#===============================================================================
# List All Packages
list_all_packages() {
    debug 1 "list_all_packages: List All Packages"

    local K
    # shellcheck disable=SC2086
    for K in $(list_sort ${!PACKAGES[*]}) ; do
        echo "PACKAGES[$K]=${PACKAGES[$K]}"
    done
    # shellcheck disable=SC2086
    for K in $(list_sort ${!RECOMMENDS[*]}) ; do
        echo "RECOMMENDS[$K]=${RECOMMENDS[$K]}"
    done
    # shellcheck disable=SC2086
    for K in $(list_sort ${!SUGGESTS[*]}) ; do
        echo "SUGGESTS[$K]=${SUGGESTS[$K]}"
    done
}

#===============================================================================
if [[ -n $ALL_PKGS ]] ; then
    list_all_packages
    exit 0
fi
if [[ -n $DIFF_DIST ]] ; then
    diff_distro
    exit 0
fi
if [[ -n $LIST_DISTROS ]] ; then
    list_distro_names
    exit 0
fi


#===============================================================================
get_md5sum() {
    local ACTIVITY=$1 FILE=${2:-}
    debug 1 "get_checksum: ACTIVITY=$ACTIVITY FILE=$FILE"

    local DIR CACHED MD5="md5sums.txt"
    DIR=$(dirname "${FILE}")
    if [[ $DIR = '.' ]] ; then unset DIR ; fi
    CACHED="$CMCACHE/$ACTIVITY-${DIR:+$DIR-}$MD5"

    if [[ ! -f "$CACHED" ]] ; then
        local URL="$ACTIVITY/${DIR:+$DIR/}$MD5"
        get_file "$URL" > "$CACHED"
    fi
    echo "$CACHED"
}

#===============================================================================
check_md5sum() {
    local ACTIVITY=$1 FILE=$2 TODIR=$3
    local DLOAD="$TODIR/$FILE"

    if [[ -f $DLOAD ]] ; then
        local CACHED
        CACHED=$(get_md5sum "$ACTIVITY" "$FILE")
        if [[ -f $CACHED ]] ; then
            local MD5
            MD5=$(awk "/  $FILE$/ {print \$1}" "$CACHED")
            if md5cmp "$DLOAD" "$MD5" ; then
                return 0
            fi
        fi
    fi
    return 1
}


#===============================================================================
# Determine Distro and release
guess_distro() {
    local DISTRO=${1:-}
    debug 1 "guess_distro: DISTRO=$DISTRO"
    local DISTRIB_SOURCE DISTRIB_ID DISTRIB_RELEASE DISTRIB_CODENAME DISTRIB_DESCRIPTION DISTRIB_ARCH
    #-------------------------------------------------------------------------------
    if [[ -f /etc/lsb-release ]] ; then
        DISTRIB_SOURCE+="/etc/lsb-release "
        source /etc/lsb-release
    fi
    #-------------------------------------------------------------------------------
    if [[ -f /etc/os-release ]] ; then
        DISTRIB_SOURCE+="/etc/os-release "
        source /etc/os-release
        DISTRIB_ID=${DISTRIB_ID:-${ID^}}
        DISTRIB_RELEASE=${DISTRIB_RELEASE:-$VERSION_ID}
        DISTRIB_DESCRIPTION=${DISTRIB_DESCRIPTION:-$PRETTY_NAME}
    fi
    #-------------------------------------------------------------------------------
    if [[ -z $DISTRIB_ID ]] ; then
        if [[ -f /usr/bin/lsb_release ]] ; then
            DISTRIB_SOURCE+="lsb_release "
            DISTRIB_ID=${DISTRIB_ID:-$(lsb_release -is 2>/dev/null)}
            DISTRIB_RELEASE=${DISTRIB_RELEASE:-$(lsb_release -rs 2>/dev/null)}
            DISTRIB_CODENAME=${DISTRIB_CODENAME:-$(lsb_release -cs 2>/dev/null)}
            DISTRIB_DESCRIPTION=${DISTRIB_DESCRIPTION:-$(lsb_release -ds 2>/dev/null)}
        fi
    fi
    #-------------------------------------------------------------------------------
    if [[ -f /etc/debian_version ]] ; then
        DISTRIB_SOURCE+="/etc/debian_version "
        DISTRIB_ID=${DISTRIB_ID:-Debian}
        [[ -n $DISTRIB_CODENAME ]] || DISTRIB_CODENAME=$(sed 's|^.*/||' /etc/debian_version)
        [[ -n $DISTRIB_RELEASE ]] || DISTRIB_RELEASE=${DEBREL[$DISTRIB_CODENAME]:-$DISTRIB_CODENAME}
    #-------------------------------------------------------------------------------
    elif [[ -f /etc/SuSE-release ]] ; then
        DISTRIB_SOURCE+="/etc/SuSE-release "
        [[ -n $DISTRIB_ID ]] || DISTRIB_ID=$(awk 'NR==1 {print $1}' /etc/SuSE-release)
        [[ -n $DISTRIB_RELEASE ]] || DISTRIB_RELEASE=$(awk '/^VERSION/ {print $3}' /etc/SuSE-release)
        [[ -n $DISTRIB_CODENAME && $DISTRIB_CODENAME != "n/a" ]] || DISTRIB_CODENAME=$(awk '/^CODENAME/ {print $3}' /etc/SuSE-release)
    #-------------------------------------------------------------------------------
    elif [[ -f /etc/redhat-release ]] ; then
        DISTRIB_SOURCE+="/etc/redhat-release "
        if grep -E -q "^Red Hat Enterprise Linux" /etc/redhat-release ; then
            [[ -n $DISTRIB_RELEASE ]] || DISTRIB_RELEASE=$(awk '{print $7}' /etc/redhat-release)
        elif [[ ${NAME:-} = "CentOS Stream" ]] ; then
            DISTRIB_ID="CentOS.Stream"
        elif grep -E -q "^CentOS|Fedora" /etc/redhat-release ; then
            DISTRIB_ID=$(awk '{print $1}' /etc/redhat-release)
            [[ -n $DISTRIB_RELEASE ]] || DISTRIB_RELEASE=$(awk '{print $3}' /etc/redhat-release)
        fi
        DISTRIB_ID=${DISTRIB_ID:-RHEL}
        [[ -n $DISTRIB_CODENAME ]] || DISTRIB_CODENAME=$(sed 's/^.*(//; s/).*$//;' /etc/redhat-release)
    #-------------------------------------------------------------------------------
    elif [[ -e /etc/arch-release ]] ; then
        DISTRIB_SOURCE+="/etc/arch-release "
        DISTRIB_ID=${DISTRIB_ID:-Arch}
        # Arch Linux doesn't have a "release"...
        # So instead we'll look at the modification date of pacman
        # shellcheck disable=SC2012
        [[ -n $DISTRIB_RELEASE ]] || DISTRIB_RELEASE=$(ls -l --time-style=+%Y.%m /bin/pacman | cut -d' ' -f6)
    #-------------------------------------------------------------------------------
    elif [[ -e /etc/gentoo-release ]] ; then
        DISTRIB_SOURCE+="/etc/gentoo-release "
        DISTRIB_ID=${DISTRIB_ID:-Gentoo}
        [[ -n $DISTRIB_RELEASE ]] || DISTRIB_RELEASE=$(cut -d' ' -f5 /etc/gentoo-release)
    fi
    #-------------------------------------------------------------------------------
    if [[ -n $DISTRO ]] ; then
        debug 1 "  Overriding distro: $DISTRO"
        DISTRIB_SOURCE+="override "
        DISTRIB_ID=${DISTRO%%-*}
        DISTRIB_RELEASE=${DISTRO##*-}
        DISTRIB_CODENAME=Override
        DISTRIB_DESCRIPTION="$DISTRO (Override)"
    fi
    #-------------------------------------------------------------------------------
    shopt -s nocasematch
    if [[ $DISTRIB_ID == Centos ]] ; then
        DISTRIB_ID=CentOS
        DISTRIB_RELEASE=${DISTRIB_RELEASE%%.*}
    elif [[ $DISTRIB_ID =~ Debian ]] ; then
        DISTRIB_RELEASE=${DEBREL[$DISTRIB_RELEASE]:-$DISTRIB_RELEASE}
    elif [[ $DISTRIB_ID == ol || $DISTRIB_ID =~ Oracle ]] ; then
        DISTRIB_ID=OracleLinux
    elif [[ $DISTRIB_ID == RedHat* || $DISTRIB_ID == Rhel ]] ; then
        DISTRIB_ID=RHEL
    elif [[ $DISTRIB_ID =~ Sles || $DISTRIB_ID =~ SLE ]] ; then
        DISTRIB_ID=SLES
    elif [[ $DISTRIB_ID =~ Suse ]] ; then
        DISTRIB_ID=openSUSE
        version_greater_equal 20000000 "$DISTRIB_RELEASE" || DISTRIB_RELEASE=999
    elif [[ -z $DISTRIB_ID ]] ; then
        DISTRIB_ID=Unknown
    fi
    shopt -u nocasematch
    #-------------------------------------------------------------------------------
    DISTRIB_RELEASE=${DISTRIB_RELEASE:-0}
    #DISTRIB_CODENAME=${DISTRIB_CODENAME:-Unknown}
    [[ -n $DISTRIB_DESCRIPTION ]] || DISTRIB_DESCRIPTION="$DISTRIB_ID $DISTRIB_RELEASE"

    #===============================================================================
    # Determine Distro arch
    local DARCH
    if [[ -e /usr/bin/dpkg && $DISTRIB_ID =~ Debian|Kubuntu|LinuxMint|Mint|Ubuntu|Xubuntu ]] ; then
        DARCH=$(dpkg --print-architecture)
    elif [[ -e /bin/rpm || -e /usr/bin/rpm ]] && [[ $DISTRIB_ID =~ CentOS|Fedora|Rhel|RHEL|openSUSE|SLES ]] ; then
        DARCH=$(rpm --eval %_arch)
    elif [[ -e /usr/bin/file ]] ; then
        DARCH=$(/usr/bin/file /usr/bin/file | cut -d, -f2)
        DARCH=${DARCH## }
        DARCH=${DARCH/-64/_64}
    else
        DARCH=Unknown
    fi
    # Because Debian and derivatives use amd64 instead of x86_64...
    if [[ "$DARCH" == "amd64" ]] ; then
        DISTRIB_ARCH=x86_64
    else
        DISTRIB_ARCH=$(sed -re 's/IBM //' <<<$DARCH)
    fi

    #===============================================================================
    debug 1 "  DISTRIB_SOURCE=$DISTRIB_SOURCE"
    debug 1 "  DISTRIB_ID=$DISTRIB_ID"
    debug 1 "  DISTRIB_RELEASE=$DISTRIB_RELEASE"
    debug 1 "  DISTRIB_CODENAME=$DISTRIB_CODENAME"
    debug 1 "  DISTRIB_DESCRIPTION=$DISTRIB_DESCRIPTION"
    debug 1 "  DISTRIB_ARCH=$DISTRIB_ARCH"
    debug 1 "  DARCH=$DARCH"
    echo "$DISTRIB_ID,$DISTRIB_RELEASE,$DISTRIB_CODENAME,$DISTRIB_DESCRIPTION,$DISTRIB_ARCH,$DARCH"
}

#===============================================================================
which_distro() {
    local ID=$1 DARCH=$2 RELEASE=$3 CODENAME=$4
    debug 1 "which_distro: ID=$ID DARCH=$DARCH RELEASE=$RELEASE CODENAME=$CODENAME"
    echo "Linux Distro: $ID${DARCH:+:$DARCH}-$RELEASE ${CODENAME:+($CODENAME)}"
    exit 0
}

#===============================================================================
extract_arch () {
    local D=$1 DIST ARCH
    read -r DIST ARCH <<< "$(sed -re 's/^([a-zA-Z0-9]+):([a-zA-Z0-9]+)(-.*)$/\1\3 \2/' <<<"$D")"
    if [[ -n $ARCH ]] ; then
        debug 2 "extract_arch: $DIST $ARCH"
        echo "$DIST $ARCH"
    else
        echo "$D"
    fi
}

#===============================================================================
include_arch () {
    local D DIST=$1 ARCH=$2
    D=$(sed -re 's/([a-zA-Z0-9]+)(-[^ ]+)?/\1'"${ARCH:+:$ARCH}"'\2/g' <<<"$DIST")
    debug 2 "    include_arch: $DIST -> $D"
    echo "${D:-$DIST}"
}

#===============================================================================
# Expand distro aliases into the real (list) of distro names
fix_distro_alias() {
    local D
    for D in "$@" ; do
        local DIST ARCH ALIAS
        # shellcheck disable=SC2086
        read -r DIST ARCH <<<"$(extract_arch $D)"
        ALIAS="${DISTRO_ALIASES[${DIST}]:-}"
        if [[ -n $ALIAS ]] ; then
            debug 2 "  fix_distro_alias: $DIST -> $ALIAS"
            include_arch "$ALIAS" "$ARCH"
        else
            debug 2 "  fix_distro_alias: $D"
            echo "$D"
        fi
    done
}

#===============================================================================
# shellcheck disable=SC2086
IFS=, read -r ID RELEASE CODENAME DESCRIPTION ARCH DARCH <<<"$(guess_distro ${DIST_LIST:-})"
debug 1 "main: guess_distro split: ID=$ID RELEASE=$RELEASE CODENAME=$CODENAME DESCRIPTION=$DESCRIPTION ARCH=$ARCH DARCH=$DARCH"
[[ -z $WHICH_DISTRO ]] || which_distro "$ID" "$ARCH" "$RELEASE" "$CODENAME"

#===============================================================================
# Expand Distro lists via distro aliases
# shellcheck disable=SC2086
[[ -z ${DISTROS:-} ]] || DISTROS=$(fix_distro_alias $DISTROS)
# shellcheck disable=SC2086
[[ -z ${DISTROS[LFD]} ]] || DISTROS[LFD]=$(fix_distro_alias ${DISTROS[LFD]})
# shellcheck disable=SC2086
[[ -z ${DISTROS[EMBEDDED]} ]] || DISTROS[EMBEDDED]=$(fix_distro_alias ${DISTROS[EMBEDDED]})
# shellcheck disable=SC2086
[[ -z ${DISTROS[LFS]} ]] || DISTROS[LFS]=$(fix_distro_alias ${DISTROS[LFS]})

#===============================================================================
# TEST: Right cpu architecture?
check_cpu() {
    local CARCH=$1
    local CPU_ARCH

    if [[ -n $ARCH ]] ; then
        CPU_ARCH=$(uname -m)
        verbose "check_cpu: CARCH='$CARCH' CPU_ARCH='$CPU_ARCH'"
        if [[ $CARCH = i386 && $CPU_ARCH = i686 ]] ; then
            pass "CPU architecture is $CARCH ($CPU_ARCH)"
        elif [[ $CPU_ARCH = "$CARCH" && -z $SIMULATE_FAILURE ]] ; then
            pass "CPU architecture is $CPU_ARCH"
        else
            fail "CPU architecture is not $CARCH (it is $CPU_ARCH)"
        fi
    fi
}

#===============================================================================
# TEST: Right cpu flags?
check_cpu_flags() {
    local FLAGS=$1
    local FLAG NOTFOUND

    if [[ -n $FLAGS ]] ; then
        verbose "check_cpu_flags: FLAGS=$FLAGS"
        for FLAG in $FLAGS ; do
             grep -qc " ${FLAG/|/\\|} " /proc/cpuinfo || NOTFOUND+=" $FLAG"
        done
        if [[ -n $NOTFOUND ]] ; then
            fail "CPU doesn't have the following capabilities:$NOTFOUND"
        else
            pass "CPU has all needed capabilities: $FLAGS"
        fi
    fi
}

#===============================================================================
get_number_of_cpus() {
    local NUM_CPU
    NUM_CPU=$(lscpu | awk '/^CPU\(s\):/ {print $2}')
    [[ -n $NUM_CPU ]] || NUM_CPU=$(grep -c ^processor /proc/cpuinfo)
    echo "${NUM_CPU:-0}"
}

#===============================================================================
# Used to pass information between check_number_of_cpus() and check_bogomips()
NOTENOUGH=

#===============================================================================
# TEST: Enough CPUS?
check_number_of_cpus() {
    local NCPUS=$1
    verbose "check_number_of_cpus: NCPUS=$NCPUS"
    local NUM_CPU

    NUM_CPU=$(get_number_of_cpus)
    if [[ -z $NUM_CPU || $NUM_CPU == 0 ]] ; then
        bug "I didn't find the number of cpus you have" "lscpu | awk '/^CPU\\(s\\):/ {print \$2}'"
    elif [[ $NUM_CPU -lt $NCPUS || -n $SIMULATE_FAILURE ]] ; then
        fail "Single core CPU: not powerful enough (require at least $NCPUS, though $PREFER_CPUS is preferred)"
        NOTENOUGH=y
    elif [[ $NUM_CPU -lt $PREFER_CPUS ]] ; then
        pass "$NUM_CPU core CPU (good enough but $PREFER_CPUS is preferred)"
    else
        pass "$NUM_CPU core CPU"
    fi
}

#===============================================================================
get_bogomips() {
    local NUM_CPU BMIPS
    NUM_CPU=$(get_number_of_cpus)
    BMIPS=$(lscpu | awk '/^BogoMIPS:/ {print $2}' | sed -re 's/\.[0-9]{2}$//')
    [[ -n $BMIPS ]] || BMIPS=$(awk '/^bogomips/ {mips+=$3} END {print int(mips + 0.5)}' /proc/cpuinfo)
    echo $(( ${NUM_CPU:-0} * ${BMIPS:-0} ))
}

#===============================================================================
# TEST: Enough BogoMIPS?
check_bogomips() {
    local BMIPS=$1
    local GUESS

    if [[ -n $BMIPS ]] ; then
        verbose "check_bogomips: BMIPS=$BMIPS"
        GUESS=$(get_bogomips)
        if [[ -z $GUESS || $GUESS == 0 ]] ; then
            bug "I didn't find the number of BogoMIPS your CPU(s) have" \
                "awk '/^bogomips/ {mips+=\$3} END {print int(mips + 0.5)}' /proc/cpuinfo"
        elif [[ $GUESS -lt $BMIPS || -n $SIMULATE_FAILURE ]] ; then
            fail "Your CPU isn't powerful enough (must be at least $BMIPS BogoMIPS cumulatively)"
        else
            if [[ -n $NOTENOUGH ]] ; then
                notice "Despite not having enough CPUs, you may still have enough speed (currently at $GUESS BogoMIPS)"
            else
                pass "Your CPU appears powerful enough (currently at $GUESS BogoMIPS cumulatively)"
            fi
        fi
    fi
}

#===============================================================================
# TEST: Enough RAM?
check_ram() {
    local MEM=$1
    verbose "check_ram: MEM=$MEM"
    local RAM_GBYTES

    RAM_GBYTES=$(awk '/^MemTotal/ {print int($2/1024/1024+0.7)}' /proc/meminfo)
    if [[ -z $RAM_GBYTES ]] ; then
        bug "I didn't how much free RAM you have" \
            "awk '/^MemTotal/ {print int(\$2/1024/1024+0.7)}' /proc/meminfo"
    elif [[ $RAM_GBYTES -lt $MEM || -n $SIMULATE_FAILURE ]] ; then
        fail "Only $RAM_GBYTES GiB RAM (you require at least $MEM GiB of RAM)"
    else
        pass "$RAM_GBYTES GiB RAM"
    fi
}

#===============================================================================
# df wrapper
get_df() {
    local DIR=$1
    local UNIT=$2

    if [[ -n $DIR ]] ; then
        local KBYTES
        KBYTES=$(df -k "$DIR" | awk '{if (NR == 2) print int($4)}')
        case $UNIT in
            MiB) echo $(( (KBYTES + 512) / 1024 ));;
            GiB) echo $(( (KBYTES + 512*1024) / 1024 / 1024));;
        esac
    fi
}

#===============================================================================
# find space on another attached drive
find_alternate_disk() {
    local MINSIZE=$1
    local UNIT=$2
    local STRING=$3
    local NOTFOUND=1 FS TOTAL USED AVAIL USE MP
    debug 1 "find_alternate_disk: Looking for disk ${STRING:+(${STRING%=})} bigger than $MINSIZE $UNIT"

    # shellcheck disable=SC2034
    while read -r FS TOTAL USED AVAIL USE MP; do
        [[ -n $MP ]] || continue
        AVAIL=$(get_df "$MP" "$UNIT")
        debug 2 "  Check MP=$MP AVAIL=$AVAIL UNIT=$UNIT"
        if [[ $AVAIL -ge $MINSIZE ]] ; then
           echo "$STRING$MP has $AVAIL $UNIT free"
           NOTFOUND=0
        fi
    done <<< "$(df | awk '{if (NR > 1) print}')"
    return $NOTFOUND
}

#===============================================================================
# TEST: Enough free disk space in $BUILDHOME? (defaults to $HOME)
check_free_disk() {
    local DSK=$1
    local BUILDHOME=$2
    [[ -n $BUILDHOME ]] || BUILDHOME=$(getent passwd "$USER" | cut -d: -f6)
    [[ -n $BUILDHOME ]] || error "No BUILDHOME specified"
    verbose "check_free_disk: DSK=$DSK BUILDHOME=$BUILDHOME"
    local DISK_GBYTES ALT

    DISK_GBYTES=$(get_df "$BUILDHOME" GiB)
    if [[ -z $DISK_GBYTES ]] ; then
        bug "I didn't find how much disk space is free in $BUILDHOME" \
            "df --output=avail $BUILDHOME | awk '{if (NR == 2) print int(($4+524288)/1048576)}'"
    elif [[ ${DISK_GBYTES:=1} -lt $DSK || -n $SIMULATE_FAILURE ]] ; then
        ALT=$(find_alternate_disk "$DSK" GiB "BUILDHOME=")
        if [[ -n $ALT ]] ; then
            warn "$BUILDHOME only has $DISK_GBYTES GiB free (need at least $DSK GiB)"
            pass "However, $ALT"
        else
            fail "only $DISK_GBYTES GiB free in $BUILDHOME (need at least $DSK GiB) Set BUILDHOME=/path/to/disk to override \$HOME"
        fi
    else
        pass "$DISK_GBYTES GiB free disk space in $HOME"
    fi
}

#===============================================================================
# TEST: Enough free disk space in /boot?
check_free_boot_disk() {
    local SIZE=$1
    local BOOTDIR=${2:-/boot}
    [[ -n $BOOTDIR ]] || error "No BOOTDIR specified"
    verbose "check_free_boot_disk: SIZE=$SIZE BOOTDIR=$BOOTDIR"
    local BOOT_MBYTES

    BOOT_MBYTES=$(get_df "$BOOTDIR" MiB)
    if [[ -z $BOOT_MBYTES ]] ; then
        bug "I didn't find how much disk space is free in $BOOTDIR" \
            "awk '/^MemTotal/ {print int(\$2/1024/1024+0.7)}' /proc/meminfo"
    elif [[ ${BOOT_MBYTES:=1} -le $SIZE || -n $SIMULATE_FAILURE ]] ; then
        fail "only $BOOT_MBYTES MiB free in /boot (need at least $SIZE MiB)"
    else
        pass "$BOOT_MBYTES MiB free disk space in /boot"
    fi
}

#===============================================================================
# TEST: Right Linux distribution architecture?
check_distro_arch() {
    local DARCH=$1
    local DARCH2=$2

    if [[ -n $DARCH2 ]] ; then
        verbose "check_distro_arch: DARCH2=$DARCH2 DARCH=$DARCH"
        if [[ -z $DARCH || -z $DARCH2 ]] ; then
            bug "Wasn't able to determine Linux distribution architecture" \
                "$0 --gather-info"
        elif [[ $DARCH != "$DARCH2" || -n $SIMULATE_FAILURE ]] ; then
            fail "The distribution architecture must be $DARCH2"
        else
            pass "Linux distribution architecture is $DARCH2"
        fi
    fi
}

#===============================================================================
# Look for the current distro in a list of distros
found_distro() {
    local ID=$1 DARCH=$2 RELEASE=$3 DISTS=$4
    local DISTRO
    debug 1 "found_distro: ID=$ID DARCH=$DARCH RELEASE=$RELEASE DISTS=$DISTS"

    for DISTRO in $DISTS ; do
        debug 2 "  found_distro: $ID:$DARCH-$RELEASE compare $DISTRO"
        local G='' R='*' A='*'
        if [[ $DISTRO = *+ ]] ; then 
            G=y
            DISTRO=${DISTRO%\+}
            debug 2 "    distro_found: $DISTRO or greater"
        fi
        if [[ $DISTRO = *-* ]] ; then
            R=${DISTRO#*-}
            DISTRO=${DISTRO%-*}
        fi
        if [[ $DISTRO = *:* ]] ; then
            A=${DISTRO#*:}
            DISTRO=${DISTRO%:*}
        fi
        local MSG="    found_distro: Are we running DISTRO=$DISTRO ARCH=$A REL=$R ${G:+or-newer }?"
        # shellcheck disable=SC2053
        if [[ $ID = "$DISTRO" && $DARCH = $A ]] ; then
            debug 2 "    found_distro: RELEASE=$RELEASE G=$G R=$R"
            if [[ $G = y && $R != "*" ]] && version_greater_equal "$RELEASE" "$R" ; then
                debug 2 "    distro_found: $RELEASE >= $R"
                R='*'
            fi
            # shellcheck disable=SC2053
            if [[ $RELEASE = $R ]] ; then
                debug 2 "$MSG Yes"
                return 0
            fi
        fi
        debug 2 "$MSG No"
    done
    return 1
}

#===============================================================================
# TEST: Blacklisted Linux distribution?
check_distro_bl() {
    local ID=$1 DARCH=$2 RELEASE=$3 CODENAME=$4 BL=$5
    debug 1 "check_distro_bl: ID=$ID DARCH=$DARCH RELEASE=$RELEASE BL=$BL"

    if [[ -n $SIMULATE_FAILURE ]] ; then
        BL=$ID-$RELEASE
    fi
    if [[ -z $ID || -z $DARCH ]] ; then
        bug "Wasn't able to determine Linux distribution" \
            "$0 --gather-info"
    elif [[ -n $BL ]] ; then
        if found_distro "$ID" "$DARCH" "$RELEASE" "$BL" ; then
            fail "This Linux distribution can't be used for this activity: $ID:$DARCH-$RELEASE ${CODENAME:+($CODENAME)}"
            [[ -n $SIMULATE_FAILURE ]] || exit 1
        fi
    fi
}

#===============================================================================
# TEST: Right Linux distribution?
check_distro() {
    local ID=$1 DARCH=$2 RELEASE=$3 CODENAME=$4 DESCRIPTION=$5 DISTS=$6
    debug 1 "check_distro: ID=$ID DARCH=$DARCH RELEASE=$RELEASE DISTS=$DISTS"

    if [[ -n $SIMULATE_FAILURE ]] ; then
        DISTS=NotThisDistro-0
    fi
    if [[ -z $DISTS ]] ; then
        notice "Currently running $DESCRIPTION (supported)"
    elif [[ -z $ID || -z $DARCH ]] ; then
        bug "Wasn't able to determine Linux distribution" \
            "$0 --gather-info"
    else
        if found_distro "$ID" "$DARCH" "$RELEASE" "$DISTS" ; then
            pass "Linux distribution is $ID:$DARCH-$RELEASE ${CODENAME:+($CODENAME)}"
        else
            warn "Linux distribution is $ID:$DARCH-$RELEASE ${CODENAME:+($CODENAME)}"
            fail "The distribution must be: $DISTS"
        fi
    fi
}

#===============================================================================
# TEST: Is the kernel configured properly?
check_kernel_config() {
    local CFGS=$1 CONFIG

    if [[ -n $CFGS ]] ; then
        verbose "check_kernel_config: CFGS=$CFGS"
        local MISSINGCONFIG KERNELCONFIG
        KERNELCONFIG=${KERNELCONFIG:-/boot/config-$(uname -r)}
        if [[ ! -f $KERNELCONFIG ]] ; then
            warn "Wasn't able to find kernel config. You can specify it by setting KERNELCONFIG=<filename>"
            return 1
        fi
        for CONFIG in $CFGS ; do
            grep -qc "CONFIG_$CONFIG" "$KERNELCONFIG" || MISSINGCONFIG+=" $CONFIG"
        done
        if [[ -z $MISSINGCONFIG ]] ; then
            pass "The Current kernel is properly configured: $CFGS"
        else
            fail "Current kernel is missing these options:$MISSINGCONFIG"
        fi
    fi
}

#===============================================================================
# TEST: Is there Internet?
#   You can set the PINGHOST environment variable in order to override the default
check_internet() {
    local NETWORK=$1
    local AVAILABLE=$2
    local PINGHOST=${3:-8.8.8.8}

    if [[ -n $NETWORK ]] ; then
        verbose "check_internet: NETWORK=$NETWORK AVAILABLE=${AVAILABLE:-n} PINGHOST=$PINGHOST"
        if [[ -n $NONETWORK ]] ; then
            warn "check_internet: No Internet because no-network selected."
        elif [[ -z $SIMULATE_FAILURE && -n $AVAILABLE ]] ; then
            pass "Internet is available (which is required in this case)"
        elif [[ -z $SIMULATE_FAILURE ]] && ping -q -c 1 "$PINGHOST" >/dev/null 2>&1 ; then
            verbose "check_internet with ping PINGHOST=$PINGHOST"
            pass "Internet is available (which is required in this case)"
        else
            fail "Internet doesn't appear to be available"
        fi
    else
        verbose "Not requiring Internet availability"
    fi
}

#===============================================================================
# We need this because lspci may not be installed
find_devices() {
    local DATA=$1
    local RETURN=$2
    debug 1 "find_devices: DATA=... RETURN=$RETURN"

    [[ -n $DATA ]] || return 1
    local DEV
    for DEV in /sys/bus/pci/devices/*; do
        local PCIID
        # shellcheck disable=SC2086
        PCIID="$(cat $DEV/vendor) $(cat $DEV/device)"
        debug 2 "  Check found device $DEV $PCIID"
        if grep -q "$PCIID" <<<"$DATA" ; then
            local RET
            RET=$(grep "$PCIID" <<<"$DATA" | cut -d' ' -f4-)
            # shellcheck disable=SC2086
            eval $RETURN="'$RET'"
            return 0
        fi
    done
    return 1
}

#===============================================================================
# Info about PCI devices for determining if we are running in a VM
# Generated by perl script on machine which has /usr/share/misc/pci.ids
# ./pcigrep | grep -i Microsoft
# Detect Hyper-V (Azure and other MS hypervisors)
HYPERV="
0x1414 0x0001 # Microsoft Corporation - MN-120 (ADMtek Centaur-C based)
0x1414 0x0002 # Microsoft Corporation - MN-130 (ADMtek Centaur-P based)
0x1414 0x5353 # Microsoft Corporation - Hyper-V virtual VGA
0x1414 0x5801 # Microsoft Corporation - XMA Decoder (Xenon)
0x1414 0x5802 # Microsoft Corporation - SATA Controller - CdRom (Xenon)
0x1414 0x5803 # Microsoft Corporation - SATA Controller - Disk (Xenon)
0x1414 0x5804 # Microsoft Corporation - OHCI Controller 0 (Xenon)
0x1414 0x5805 # Microsoft Corporation - EHCI Controller 0 (Xenon)
0x1414 0x5806 # Microsoft Corporation - OHCI Controller 1 (Xenon)
0x1414 0x5807 # Microsoft Corporation - EHCI Controller 1 (Xenon)
0x1414 0x580a # Microsoft Corporation - Fast Ethernet Adapter (Xenon)
0x1414 0x580b # Microsoft Corporation - Secure Flash Controller (Xenon)
0x1414 0x580d # Microsoft Corporation - System Management Controller (Xenon)
0x1414 0x5811 # Microsoft Corporation - Xenos GPU (Xenon)
"
# ./pcigrep Virtio
KVM="
0x1af4 0x1000 # Red Hat, Inc - Virtio network device
0x1af4 0x1001 # Red Hat, Inc - Virtio block device
0x1af4 0x1002 # Red Hat, Inc - Virtio memory balloon
0x1af4 0x1003 # Red Hat, Inc - Virtio console
0x1af4 0x1004 # Red Hat, Inc - Virtio SCSI
0x1af4 0x1005 # Red Hat, Inc - Virtio RNG
0x1af4 0x1009 # Red Hat, Inc - Virtio filesystem
0x1af4 0x1110 # Red Hat, Inc - Virtio Inter-VM shared memory
"
# ./pcigrep QEMU
QEMU="
0x1013 0x1100 # Cirrus Logic - QEMU Virtual Machine
0x1022 0x1100 # Advanced Micro Devices, Inc. [AMD] - QEMU Virtual Machine
0x1033 0x1100 # NEC Corporation - QEMU Virtual Machine
0x106b 0x1100 # Apple Inc. - QEMU Virtual Machine
0x10ec 0x1100 # Realtek Semiconductor Co., Ltd. - QEMU Virtual Machine
0x10ec 0x1100 # Realtek Semiconductor Co., Ltd. - QEMU Virtual Machine
0x1106 0x1100 # VIA Technologies, Inc. - QEMU Virtual Machine
0x1af4 0x1100 # Red Hat, Inc - QEMU Virtual Machine
0x1b36 0x0001 # Red Hat, Inc. - QEMU PCI-PCI bridge
0x1b36 0x0002 # Red Hat, Inc. - QEMU PCI 16550A Adapter
0x1b36 0x1100 # Red Hat, Inc. - QEMU Virtual Machine
0x1b36 0x0003 # Red Hat, Inc. - QEMU PCI Dual-port 16550A Adapter
0x1b36 0x1100 # Red Hat, Inc. - QEMU Virtual Machine
0x1b36 0x0004 # Red Hat, Inc. - QEMU PCI Quad-port 16550A Adapter
0x1b36 0x1100 # Red Hat, Inc. - QEMU Virtual Machine
0x1b36 0x0005 # Red Hat, Inc. - QEMU PCI Test Device
0x1b36 0x1100 # Red Hat, Inc. - QEMU Virtual Machine
0x1b36 0x1100 # Red Hat, Inc. - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - Qemu virtual machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x5845 # Intel Corporation - QEMU NVM Express Controller
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - Qemu virtual machine
0x8086 0x1100 # Intel Corporation - Qemu virtual machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - QEMU Virtual Machine
0x8086 0x1100 # Intel Corporation - Qemu virtual machine
"
# ./pcigrep | grep Parallels
PARALLELS="
0x1ab8 0x4000 # Parallels, Inc. - Virtual Machine Communication Interface
0x1ab8 0x4005 # Parallels, Inc. - Accelerated Virtual Video Adapter
0x1ab8 0x4006 # Parallels, Inc. - Memory Ballooning Controller
"
# ./pcigrep VirtualBox
VBOX="
0x80ee 0xbeef # InnoTek Systemberatung GmbH - VirtualBox Graphics Adapter
0x80ee 0xcafe # InnoTek Systemberatung GmbH - VirtualBox Guest Service
"
# ./pcigrep | grep -i VMware
VMWARE="
0x15ad 0x0405 # VMware - SVGA II Adapter
0x15ad 0x0710 # VMware - SVGA Adapter
0x15ad 0x0720 # VMware - VMXNET Ethernet Controller
0x15ad 0x0740 # VMware - Virtual Machine Communication Interface
0x15ad 0x0770 # VMware - USB2 EHCI Controller
0x15ad 0x0774 # VMware - USB1.1 UHCI Controller
0x15ad 0x0778 # VMware - USB3 xHCI Controller
0x15ad 0x0790 # VMware - PCI bridge
0x15ad 0x07a0 # VMware - PCI Express Root Port
0x15ad 0x07b0 # VMware - VMXNET3 Ethernet Controller
0x15ad 0x07c0 # VMware - PVSCSI SCSI Controller
0x15ad 0x07e0 # VMware - SATA AHCI controller
0x15ad 0x0801 # VMware - Virtual Machine Interface
0x15ad 0x0800 # VMware - Hypervisor ROM Interface
0x15ad 0x1977 # VMware - HD Audio Controller
0xfffe 0x0710 # VMWare Inc (temporary ID) - Virtual SVGA
"
# ./pcigrep | grep -i XenSource
XEN="
0x5853 0x0001 # XenSource, Inc. - Xen Platform Device
0x5853 0xc110 # XenSource, Inc. - Virtualized HID
0x5853 0xc147 # XenSource, Inc. - Virtualized Graphics Device
0xfffd 0x0101 # XenSource, Inc. - PCI Event Channel Controller
"

#===============================================================================
# TEST: Is this a VM?
check_for_vm() {
    local VMOK=$1
    local NATIVE=${2:-}
    debug 1 "check_for_vm: NATIVE=$NATIVE VMOK=$VMOK"

    shopt -s nocasematch
    if [[ -n $NATIVE || $VMOK == n || $VMOK =~ Discouraged ]] ; then
        local ACTION INVM VMREASON HV
        if [[ $VMOK =~ Discouraged ]] ; then
            ACTION=warn
            VMREASON="which is $VMOK for this course"
        else
            ACTION=fail
            VMREASON="which is not possible for this course"
        fi
        HV=$(lscpu | grep "^Hypervisor vendor:" | sed 's/^.*: *//')
        if [[ -n $HV ]] ; then
            $ACTION "You're using a virtual machine ($HV) $VMREASON"
            INVM=y
        elif find_devices "$HYPERV" INVM ; then
            $ACTION "You're in Hyper-V (or Azure) $VMREASON (Found: $INVM)"
        elif find_devices "$KVM" INVM ; then
            $ACTION "You're in KVM $VMREASON (Found: $INVM)"
        elif find_devices "$QEMU" INVM ; then
            $ACTION "You're in QEMU $VMREASON (Found: $INVM)"
        elif find_devices "$PARALLELS" INVM ; then
            $ACTION "You're in Parallels $VMREASON (Found: $INVM)"
        elif find_devices "$VBOX" INVM ; then
            $ACTION "You're in VirtualBox $VMREASON (Found: $INVM)"
        elif find_devices "$VMWARE" INVM ; then
            $ACTION "You're in VMWare $VMREASON (Found: $INVM)"
        elif find_devices "$XEN" INVM ; then
            $ACTION "You're in Xen $VMREASON (Found: $INVM)"
        fi
        debug 1 "  check_for_vm: INVM=$INVM"
        if [[ -n $INVM ]] ; then
            [[ $ACTION == warn ]] && WARNINGS=y || FAILED=y
        else
            if [[ $NATIVE =~ $RECOMMENDED || $NATIVE =~ $REQUIRED ]] ; then
                NLREASON=" which is $NATIVE for this course"
            fi
            pass "You are running Linux natively$NLREASON"
        fi
    fi
    if [[ $VMOK =~ nested ]] ; then
        local NESTED="/sys/module/kvm_intel/parameters/nested" CANNEST=N
        if [[ -f $NESTED ]] ; then
            CANNEST=$(cat "$NESTED")
        fi
        if [[ $CANNEST == Y ]] ; then
            pass "Your CPU can do nested virtualization"
        else
            fail "Your CPU isn't configured to do nested virtualization which is required for this course"
            notice "Try to enable it by booting with kvm-intel.nested=1 argument on the kernel command line and try again."
            warn "Your CPU may or may not be able to support nested virtualization. You'll have to try and see if it is"
        fi
    fi
}

#===============================================================================
if [[ -n $DETECT_VM ]] ; then
    check_for_vm "nested Discouraged"
    exit 0
fi

#===============================================================================
# TEST: Are these symlink patterns satisfied?
check_symlinks() {
    local LINKS=$1
    local ENTRY FILE PAT L
    debug 1 "check_symlinks: LINKS=$LINKS"

    for ENTRY in $LINKS; do
        IFS=: read -r FILE PAT <<<"$ENTRY"
        if [[ ! -L $FILE ]] ; then
            verbose "$FILE isn't a symlink ($PAT)"
            continue
        fi
        L=$(readlink "$FILE")
        [[ -z $SIMULATE_FAILURE ]] || L+="ERROR"
        debug 2 "FILE=$FILE PAT=$PAT L=$L"
        case $PAT in
            !*) debug 2 "!* FILE=$FILE PAT=$PAT L=$L"
                if [[ ! $L =~ ${PAT#!} ]] ; then
                    verbose "Symlink $FILE isn't $PATH ($L)"
                else
                    fail "Symlink $FILE is $L (${PAT#!})"
                fi ;;
            *) debug 2 "* FILE=$FILE PAT=$PAT L=$L"
                if [[ $L =~ $PAT ]] ; then
                    verbose "Symlink $FILE is $L ($PAT)"
                else
                    fail "Symlink $FILE isn't ${PAT#!}"
                fi ;;
        esac
    done
}

#===============================================================================
# TEST: Check versions of tools.
check_versions() {
    local VERS=$1
    local ENTRY CMD VER V
    debug 1 "check_versions: VERS=$VERS"

    for ENTRY in $VERS ; do
        IFS=: read -r CMD VER <<<"$ENTRY"
        V=$($CMD --version 2>&1 | sed -re 's/[a-zA-Z ]+//g')
        [[ -z $SIMULATE_FAILURE ]] || V=999;
        case $VER in
            \<*) if ! version_greater_equal "$V" "${VER#<}" ; then
                    verbose "Version for $CMD: $V $VER"
                else
                    fail "Version for $CMD: $V !$VER"
                fi ;;
            =*) if [[ $V = "${VER#=}" ]] ; then
                    verbose "Version for $CMD: $V $VER"
                else
                    fail "Version for $CMD: $V !$VER"
                fi ;;
            \>*) if version_greater_equal "$V" "${VER#>}" ; then
                    verbose "Version for $CMD: $V $VER"
                else
                    fail "Version for $CMD: $V !$VER"
                fi ;;
            *)  if [[ $V =~ $VER ]] ; then
                    verbose "Version for $CMD: $V =~ $VER"
                else
                    fail "Version for $CMD: $V !~ $VER"
                fi ;;
        esac
    done
}

#===============================================================================
check_all() {
    check_cpu "$ARCH"
    check_cpu_flags "$CPUFLAGS"
    check_number_of_cpus "$CPUS"
    check_bogomips "$BOGOMIPS"
    check_ram "$RAM"
    check_free_disk "$DISK" "${BUILDHOME:-$HOME}"
    check_free_boot_disk "$BOOT" "${BOOTDIR:-}"
    check_distro_arch "$ARCH" "$DISTRO_ARCH"
    check_distro_bl "$ID" "$DARCH" "$RELEASE" "$CODENAME" "$DISTRO_BL"
    check_distro "$ID" "$DARCH" "$RELEASE" "$CODENAME" "$DESCRIPTION" "${DISTROS:-}"
    check_kernel_config "$CONFIGS"
    check_internet "$INTERNET" "$INTERNET_AVAILABLE" "${PINGHOST:-}"
    check_for_vm "$VMOKAY" "$NATIVELINUX"
    check_symlinks "$SYMLINKS"
    check_versions "$VERSIONS"
}


EPELURL="http://download.fedoraproject.org/pub/epel"

#===============================================================================
# See whether sudo is available
check_sudo() {
    local DID=$1 DREL=$2
    if ! sudo -V >/dev/null 2>&1 ; then
        [[ $USER == root ]] || warn "sudo isn't installed, so you will have to run these commands as root instead"
        # Provide sudo wrapper for try_packages
        sudo() {
             if [[ $USER == root ]] ; then
                 "$@"
             else
                 highlight "Please enter root password to run the following as root"
                 highlight "$*" >&2
                 su -c "$*" root
             fi
        }
        INSTALL=y NO_CHECK=y NO_PASS=y NO_WARN=y try_packages "$DID" "$DREL" ACTIVITY sudo
        unset sudo
        if [[ -f /etc/sudoers ]] ; then
            # Add $USER to sudoers
            highlight "Please enter root password to add yourself to sudoers"
            su -c "sed -ie 's/^root\(.*ALL$\)/root\1\n$USER\1/' /etc/sudoers" root
        fi
        highlight "From now on you will be asked for your user password"
    fi
}

#===============================================================================
# Should we use dnf or yum on RHEL derivatives?
get_dnf() {
        if [[ -e /bin/dnf || -e /usr/bin/dnf ]] ; then
            echo dnf
        else
            echo yum
        fi
}
YUM="$(get_dnf)"

#===============================================================================
check_repos() {
    local ID=$1
    local RELEASE=$2
    local CODENAME=$3
    local DARCH=$4
    local CHANGES='' REPOS SECTION
    debug 1 "check_repos: ID=$ID RELEASE=$RELEASE CODENAME=$CODENAME DARCH=$DARCH"
    verbose "Checking installed repos"

    #-------------------------------------------------------------------------------
    if [[ $ID == Debian ]] ; then
        debug 2 "  Check repos for Debian"
        REPOS="contrib non-free"
        local LISTFILE=/etc/apt/sources.list.d/debian.list
        # shellcheck disable=SC2046
        for SECTION in $REPOS ; do
            # shellcheck disable=SC2016
            while read -r LINE ; do
                [[ -n $LINE ]] || continue
                debug 2 "    Is '$LINE' enabled?"
                [[ -f $LISTFILE ]] || sudo touch $LISTFILE
                if ! grep -h -q "$LINE" $LISTFILE ; then
                    echo "$LINE" | sudo tee -a $LISTFILE
                    verbose "Adding '$LINE' to $LISTFILE"
                    CHANGES=y
                fi
            done <<< "$(grep -h "deb .*debian.* main" /etc/apt/sources.list \
                $(if [[ -f $LISTFILE ]] ; then echo "$LISTFILE" ; fi) \
                | sed -e '/^#/d; /"$SECTION"/d; s/main.*/'"$SECTION"'/')"
        done
        if [[ -n $CHANGES ]] ; then
            notice "Enabling $REPOS in sources.list... updating"
            sudo apt-get -qq update
        fi

    #-------------------------------------------------------------------------------
    elif [[ $ID =~ Alma|CentOS|RHEL|Rocky ]] ; then
        debug 2 "  Check repos for CentOS|RHEL"
        if [[ $YUM =~ dnf ]] ; then
                sudo "$YUM" -y install dnf-plugins-core
        fi
        if rpm -q epel-release >/dev/null ; then
            verbose "epel is already installed"
        else
            case "$RELEASE" in
                7*) EPEL="$EPELURL/epel-release-latest-7.noarch.rpm" ;;
                *)  EPEL="$EPELURL/epel-release-latest-8.noarch.rpm" ;;
            esac
            if [[ -n $EPEL ]] ; then
                notice "Installing epel in ${ID}..."
                sudo "$YUM" -y install "$EPEL"
            fi
        fi
        if [[ $YUM =~ dnf ]] ; then
            sudo "$YUM" config-manager --set-enabled PowerTools
        fi

    #-------------------------------------------------------------------------------
    elif [[ $ID == Ubuntu ]] ; then
        debug 2 "  Check repos for Ubuntu"
        REPOS="universe multiverse"
        for SECTION in $REPOS ; do
            local DEB URL DIST SECTIONS
            # shellcheck disable=SC2094
            while read -r DEB URL DIST SECTIONS ; do
                [[ $DEB = deb-src ]] || continue
                [[ $URL =~ http && $DIST =~ $CODENAME && $SECTIONS =~ main ]] || continue
                if [[ $URL =~ archive.canonical.com || $URL =~ extras.ubuntu.com ]] ; then continue ; fi
                debug 2 "    $ID: is $SECTION enabled for $URL $DIST $SECTIONS"
                # shellcheck disable=2094
                if ! grep -E -q "^$DEB $URL $DIST .*$SECTION" /etc/apt/sources.list ; then
                    verbose "Running: sudo add-apt-repository '$DEB $URL $DIST $SECTION'"
                    sudo add-apt-repository "$DEB $URL $DIST $SECTION"
                    CHANGES=y
                fi
            done </etc/apt/sources.list
        done
        if [[ -n $CHANGES ]] ; then
            notice "Enabling $REPOS in sources.list... updating"
            sudo apt-get -qq update
        fi
    fi
}

#===============================================================================
BUILDDEPSTR=build-dep_
no_build_dep() {
    # shellcheck disable=SC2001
    sed 's/ /\n/g' <<<"$@" | sed -e "/$BUILDDEPSTR/d"
}

#===============================================================================
only_build_dep() {
    # shellcheck disable=SC2001
    sed 's/ /\n/g' <<<"$@" | sed "/$BUILDDEPSTR/!d; s/$BUILDDEPSTR//g"
}

#===============================================================================
RFCONFIG="$HOME/.config/${CMDBASE%.sh}"
clear_installed() {
    if [[ -n $ALL_ACTIVITIES ]] ; then
        $DRYRUN rm -f "$RFCONFIG"/*-installed-packages.list
    else
        local ACTIVITY FILE
        # shellcheck disable=SC2048
        for ACTIVITY in $* ; do
            FILE="$RFCONFIG/${ACTIVITY}-installed-packages.list"
            if [[ -f $FILE ]] ; then
                $DRYRUN rm "$FILE"
            fi
        done
    fi
}

#===============================================================================
read_installed() {
    if [[ -n $ALL_ACTIVITIES ]] ; then
        cat "$RFCONFIG"/*-installed-packages.list
    else
        local ACTIVITY FILE
        for ACTIVITY in "$@" ; do
            FILE="$RFCONFIG/${ACTIVITY}-installed-packages.list"
            if [[ -f $FILE ]] ; then
                cat "$FILE"
            fi
        done
    fi
}

#===============================================================================
save_installed() {
    local ACTIVITY FILE
    ACTIVITY=$(head -1 <<<"$1"); shift
    mkdir -p "$RFCONFIG"
    FILE="$RFCONFIG/${ACTIVITY%% *}-installed-packages.list"
    debug 1 "Saving installed packages ($*) to file: $FILE"
    # shellcheck disable=SC2001
    echo "$*" | sed -e 's/ /\n/g' >>"$FILE"
}

#===============================================================================
deb_check() {
    verbose "Check dpkg is in a good state"
    while [[ $( (dpkg -C 2>/dev/null || sudo dpkg -C) | wc -l) -gt 0 ]] ; do
        local PKG FILE
        if sudo dpkg -C | grep -q "missing the md5sums" ; then
            for PKG in $(sudo dpkg -C | awk '/^ / {print $1}') ; do
                [[ ! -f /var/lib/dpkg/info/${PKG}.md5sums ]] || continue
                if warn_wait "The md5sums for $PKG need updating. Can I fix it?" ; then
                    for FILE in $(sudo dpkg -L "$PKG" | grep -v "^/etc" | sort) ; do
                        if [[ -f $FILE && ! -L $FILE ]] ; then
                            md5sum "$FILE"
                        fi
                    done | sed 's|/||' | sudo tee "/var/lib/dpkg/info/${PKG}.md5sums" >/dev/null
                fi
            done
            verbose "Updated all missing MD5SUM files"
        else
            if warn_wait "dpkg reports some issues with the package system. I can't continue without these being fixed.\n    Is it okay if I try a \"dpkg --configure -a\"?" ; then
                sudo dpkg --configure -a
                verbose "Attempted to configure all unconfigured packages"
            fi
        fi
    done
}

#===============================================================================
# Install packages with apt-get
debinstall() {
    local PKGLIST BDLIST NEWPKG
    local ACTIVITY=$1; shift
    PKGLIST=$(no_build_dep "$@")
    BDLIST=$(only_build_dep "$@")
    if [[ -z $PKGLIST && -z $BDLIST ]] ; then
        return 0
    fi
    # shellcheck disable=SC2086
    debug 1 "debinstall: "$*

    deb_check

    local APTGET="apt-get --no-install-recommends ${FIXMISSING:+--fix-missing}"
    # Check for packages which can't be found
    if [[ -n $PKGLIST ]] ; then
        local ERRPKG
        # shellcheck disable=SC2086
        ERRPKG=$($APTGET --dry-run install $PKGLIST 2>&1 \
            | awk '/^E: Package/ {print $3}; /^E: Unable to correct/ {print $2}; /^E: Unable/ {print $6}' \
            | sed -e "/-f/d; s/'//g")
        if [[ $ERRPKG =~ Unable ]] ; then
            # shellcheck disable=SC2086
            $APTGET --dry-run install $PKGLIST
            $DRYRUN sudo dpkg --audit
            error "Unable to install package list, or your packaging system is in an inconsistent state"
        elif [[ -n $ERRPKG ]] ; then
            warn "Can't find package(s) in index: $ERRPKG"
            echo "Looks like you may need to run 'sudo apt-get update' and try this again"
            MISSING_PACKAGES=y
            return 0
        fi
    fi

    # Find new packages which need installing
    # shellcheck disable=SC2046
    NEWPKG=$(list_sort $(
        # shellcheck disable=SC2086
        [[ -z $PKGLIST ]] || $APTGET --dry-run install $PKGLIST | awk '/^Inst / {print $2}';
        # shellcheck disable=SC2086
        [[ -z $BDLIST ]] || $APTGET --dry-run build-dep $BDLIST | awk '/^Inst / {print $2}'))
    [[ -z $SIMULATE_FAILURE ]] || NEWPKG=$PKGLIST
    if [[ -z $NEWPKG ]] ; then
        pass "All required packages are already installed"
        return 0
    else
        warn "Some packages are missing"
        WARNINGS=y
        MISSING_PACKAGES=y
        if [[ -z $INSTALL ]] ; then
            #notice "Need to install:" $NEWPKG
            fix_missing "You can install missing packages" \
                    "$0 --install $ACTIVITY" \
                    "sudo $APTGET install $NEWPKG"
        else
            local CONTINUE=
            if [[ -n $YES ]] ; then
                debug 1 "  debinstall: always --yes, so not asking; just continue."
                CONTINUE=y
            else
                # shellcheck disable=SC2086
                ask "About to install:" $NEWPKG "\nIs that okay? [y/N]"
                local CONFIRM
                read -r CONFIRM
                case $CONFIRM in
                    y*|Y*|1) CONTINUE=y;;
                esac
            fi
            if [[ -n $CONTINUE ]]  ; then
                # shellcheck disable=SC2086
                $DRYRUN sudo $APTGET install $NEWPKG
                if [[ -z ${NO_CHECK:-} ]] ; then
                    # shellcheck disable=SC2086
                    FAILPKG=$( (sudo $APTGET --dry-run install $PKGLIST | awk '/^Conf / {print $2}') 2>&1 )
                    if [[ -n $FAILPKG ]] ; then
                        warn "Some packages didn't install: $FAILPKG"
                        fix_missing "You can perhaps try installing" \
                            "$0 --fix-missing --install $ACTIVITY" \
                            "sudo $APTGET --fix-missing install $FAILPKG"
                        WARNINGS=y
                    else
                        save_installed "$ACTIVITY" "$NEWPKG"
                        pass "All required packages are now installed"
                        unset MISSING_PACKAGES
                        return 0
                    fi
                fi
            fi
        fi
    fi
    return 1
}

#===============================================================================
# Install packages with yum or zypper
rpminstall() {
    local ACTIVITY=$1; shift
    local TOOL=$1; shift
    local PKGLIST=$*
    [[ -n $PKGLIST ]] || return 0
    debug 1 "rpminstall: TOOL=$TOOL $PKGLIST"
    local NEWPKG
    local IGNORE="--skip-broken"
    [[ $TOOL != zypper ]] || IGNORE="-i"

    # shellcheck disable=SC2046,SC2086
    NEWPKG=$(list_sort $(rpm -q $PKGLIST | awk '/is not installed$/ {print $2}'))
    [[ -z $SIMULATE_FAILURE ]] || NEWPKG=$PKGLIST
    if [[ -z $NEWPKG ]] ; then
        pass "All required packages are already installed"
        return 0
    else
        warn "Some packages are missing"
        #notice "Need to install:" $NEWPKG
        if [[ -z $INSTALL ]] ; then
            fix_missing "You can install missing packages" \
                    "$0 --install $ACTIVITY" \
                    "sudo $TOOL install $NEWPKG"
            MISSING_PACKAGES=y
        else
            # shellcheck disable=SC2086
            sudo $TOOL $IGNORE install $NEWPKG
            if [[ -z ${NO_CHECK:-} ]] ; then
                # shellcheck disable=SC2086
                FAILPKG=$(rpm -q $PKGLIST | awk '/is not installed$/ {print $2}')
                if [[ -n $FAILPKG ]] ; then
                    warn "Some packages didn't install: $FAILPKG"
                    fix_missing "You can perhaps try installing" \
                        "$0 --fix-missing --install $ACTIVITY" \
                        "sudo $TOOL $IGNORE install $FAILPKG"
                    WARNINGS=y
                else
                    save_installed "$ACTIVITY" "$NEWPKG"
                    pass "All required packages are now installed"
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

#===============================================================================
# Install packages with pacman
pacinstall(){
    local ACTIVITY=$1; shift
    local PKGLIST=$*
    [[ -n $PKGLIST ]] || return 0
    debug 1 "pacinstall: Activity=${ACTIVITY} ${PKGLIST}"
    local NEWPKG NEWAUR PACPKG AURPKG

    for PKG in $PKGLIST; do
        if [[ $PKG =~ aur: ]]; then
           PACPKG="$PACPKG $PKG"
        else
           AURPKG="$AURPKG ${PKG/aur:/}"
        fi
    done

    debug 2 "Arch packages: $PACPKG, AUR packages: $AURPKG"
    # shellcheck disable=SC2086
    NEWPKG=$(pacman -Q $PACPKG 2>&1 | awk '/was not found$/ {print $3}' | sed "s/'//g" )

    if [[ -n $AURPKG ]]; then
        # shellcheck disable=SC2086
        NEWAUR=$(pacman -Q $AURPKG 2>&1 | awk '/was not found$/ {print $3}' | sed "s/'//g" )
    fi

    if [[ -n $SIMULATE_FAILURE ]] ; then
        NEWPKG=$PACPKG
        NEWAUR=$AURPKG
    fi

    debug 2 "$NEWPKG $NEWAUR"
    if [[ -z $NEWPKG && -z $NEWAUR ]]; then
        pass "All required packages are already installed"
        return 0
    else
        warn "Some packages are missing"
        # shellcheck disable=SC2086
        [[ -z $NEWPKG ]] || notice "Need to install Arch packages:" $NEWPKG
        # shellcheck disable=SC2086
        [[ -z $NEWAUR ]] || notice "Need to install Arch AUR packages:" $NEWAUR

        if [[ -z $INSTALL ]]; then
            local MSG
            [[ -z $NEWPKG ]] || MSG="sudo pacman -S $NEWPKG"
            [[ -z $NEWAUR ]] || MSG=$MSG"\n   AUR packages: $NEWAUR should be installed with your preferred AUR process"

            fix_missing "You can install missing packages" \
                "$0 install $ACTIVITY" "$MSG"

            WARNINGS=y
            MISSING_PACKAGES=y
        else
            warn "Some Arch Linux packages are mutually exclusive, i.e. gcc and gcc-multilib."
            notice "Please review the list of missing packages and validate."
            notice "Your environment will not be harmed before continuing."

            # shellcheck disable=SC2086
            ask "About to install:" $NEWPKG "\nIs that okay? [y/N]"
            local CONFIRM
            read -r CONFIRM
            case $CONFIRM in
                y*|Y*|1) CONTINUE=y;;
            esac

            if [[ $CONTINUE == y ]]; then
                # shellcheck disable=SC2086
                $DRYRUN sudo pacman -S $NEWPKG

                # Installing some AUR packages is simple, as the block below demonstrates, but some AUR packages may
                # have dependencies that are also AUR packages.  It will be necessary to actually parse the package,
                # interpret dependencies, check if they are AUR packages, and the clone, build, and install them.  This
                # process would also have to be recursive.
                # Dependencies within dependencies within dependencies...  AURception.  Arch users should be capable of
                # handling this in stride during a session.  I did.
                #
                # TEMPDIR="$(mktemp -d $0.aur.XXXX)"
                # trap "rm -rf '$TEMPDIR'" 0               # EXIT
                # trap "rm -rf '$TEMPDIR'; exit 1" 2       # INT
                # trap "rm -rf '$TEMPDIR'; exit 1" 1 15    # HUP TERM
                #
                # CURDIR="$(pwd)"
                # cd $TEMPDIR
                #
                # for CLONE in ${NEWAUR}; do
                #     $(git clone "https://aur.archlinux.org/${CLONE}.git")
                #     cd ./$CLONE
                #     makepkg -isr
                #     cd ..
                # done
                #
                # cd $CURDIR
                # rm -rf $TEMPDIR
            fi

            if [[ -z $NO_CHECK ]]; then
                # shellcheck disable=SC2086
                FAILPKG=$(pacman -Q $PACPKG 2>&1 | awk '/was not found$/ {print $3}' | sed "s/'//g" )

                if [[ -n $FAILPKG ]] ; then
                    warn "Some packages didn't install: $FAILPKG"
                    WARNINGS=y
                else
                    save_installed "$ACTIVITY" "$NEWPKG"

                    if [[ -z $NEWAUR ]]; then
                        pass "All required packages are now installed"
                    else
                        # shellcheck disable=SC2086
                        warn "AUR packages must be installed manually:" $NEWAUR
                    fi
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

#===============================================================================
# Run extra code based on distro, release, and activity
run_extra_code() {
    local DID=$1
    local DREL=$2
    local ACTIVITY=$3
    local CODE
    debug 1 "run_extra_code: DID=$DID DREL=$DREL ACTIVITY=$ACTIVITY"

    for KEY in $DID-${DREL}_$ACTIVITY ${DID}_$ACTIVITY $ACTIVITY $DID-$DREL $DID ; do
        CODE=${RUNCODE[${KEY:-no_code_key}]:-}
        if [[ -n $CODE ]] ; then
            debug 2 "  run exra setup code for $KEY -> eval $CODE"
            eval "$CODE $ACTIVITY"
            return 0
        fi
    done
}

#===============================================================================
# TEST: Are the correct packages installed?
try_packages() {
    local ID=$1; shift
    local RELEASE=$1; shift
    local ACTIVITY
    ACTIVITY=$(strip_versions "$1"); shift
    local PKGLIST
    PKGLIST=$(list_sort "$@")
    # shellcheck disable=SC2086,SC2116
    debug 1 "try_packages: ID=$ID RELEASE=$RELEASE ACTIVITY=$(echo $ACTIVITY) PKGLIST="$PKGLIST

    #-------------------------------------------------------------------------------
    if [[ $ID =~ Debian|Kubuntu|LinuxMint|Mint|Ubuntu|Xubuntu ]] ; then
        # shellcheck disable=SC2086
        debinstall "$ACTIVITY" $PKGLIST || true
        # shellcheck disable=SC2086
        for_each_activity "run_extra_code $ID $RELEASE" $ACTIVITY

    #-------------------------------------------------------------------------------
    elif [[ $ID =~ CentOS|Fedora|RHEL ]] ; then
        # shellcheck disable=SC2086
        rpminstall "$ACTIVITY" "$YUM" $PKGLIST || true
        # shellcheck disable=SC2086
        for_each_activity "run_extra_code $ID $RELEASE" $ACTIVITY

    #-------------------------------------------------------------------------------
    elif [[ $ID =~ openSUSE|SLES ]] ; then
        # shellcheck disable=SC2086
        rpminstall "$ACTIVITY" zypper $PKGLIST || true
        # shellcheck disable=SC2086
        for_each_activity "run_extra_code $ID $RELEASE" $ACTIVITY

    #-------------------------------------------------------------------------------
    elif [[ $ID == "Arch" ]]  ; then
        # shellcheck disable=SC2086
        pacinstall "$ACTIVITY" $PKGLIST
        notice "Any AUR packages installed for this activity will need to be removed manually"
        # shellcheck disable=SC2086
        for_each_activity "run_extra_code $ID $RELEASE" $ACTIVITY

    #-------------------------------------------------------------------------------
    elif [[ $ID == "Gentoo" ]]  ; then
    # TODO: Add support for emerge here to provide similar functionality as apt-get code above
        warn "Currently there is no package support for Gentoo"
        # shellcheck disable=SC2086
        for_each_activity "run_extra_code $ID $RELEASE" $ACTIVITY
    fi
}

#===============================================================================
# Remove packages installed by this script
rm_packages() {
    local ID=$1; shift
    local RELEASE=$1; shift
    local ACTIVITY=$1; shift
    local PKGLIST
    # shellcheck disable=2086
    PKGLIST=$(read_installed $ACTIVITY)
    # shellcheck disable=SC2116,SC2086
    debug 1 "rm_packages: ID=$ID RELEASE=$RELEASE ACTIVITY=$(echo $ACTIVITY) PKGLIST="$PKGLIST

    # shellcheck disable=SC2116,SC2086
    warn_wait "About to remove: $(echo $PKGLIST)\nShould I continue?" || return 0

    #-------------------------------------------------------------------------------
    if [[ $ID =~ Debian|Kubuntu|LinuxMint|Mint|Ubuntu|Xubuntu ]] ; then
        # shellcheck disable=SC2086
        $DRYRUN sudo dpkg --purge $PKGLIST

    #-------------------------------------------------------------------------------
    elif [[ $ID =~ CentOS|Fedora|RHEL ]] ; then
        # shellcheck disable=SC2086
        $DRYRUN sudo "$YUM" remove $PKGLIST

    #-------------------------------------------------------------------------------
    elif [[ $ID =~ openSUSE|SLES ]] ; then
        # shellcheck disable=SC2086
        $DRYRUN sudo zypper remove $PKGLIST

    #-------------------------------------------------------------------------------
    elif [[ $ID == "Arch" ]]  ; then
        local ARCHLIST
        ARCHLIST=${PKGLIST/aur:/}
        # shellcheck disable=SC2086
        debug 2 "Removing Arch packages:" $PKGLIST
        # shellcheck disable=SC2086
        $DRYRUN sudo pacman -Rs $ARCHLIST

    #-------------------------------------------------------------------------------
    elif [[ $ID == "Gentoo" ]]  ; then
    # TODO: Add support for emerge here to provide similar functionality as apt-get code above
        warn "Currently there is no package support for Gentoo"
    fi

    clear_installed "$ACTIVITY"
}

#===============================================================================
if [[ -n $REMOVE ]] ; then
    rm_packages "$ID" "$RELEASE" "$COURSE"
    exit 0
fi


#===============================================================================
setup_meta() {
    local ACTIVITY=$1
    debug 1 "setup_meta: ACTIVITY=$ACTIVITY"

    local ATTR
    local ATTRS="EMBEDDED MOOC SELFPACED INPERSON VIRTUAL INSTR_LED_CLASS
                 SELFPACED_CLASS PREREQ INTERNET NATIVELINUX VMOKAY VMS
                 OS_NEEDS OS ARCH CPUS PREFER_CPUS CPUFLAGS BOGOMIPS RAM DISK
                 BOOT CONFIGS DISTRO_ARCH DISTROS DISTRO_BL SYMLINKS VERSIONS
                 EXTRAS"

    for ATTR in $ATTRS ; do
        # shellcheck disable=SC1087
        eval "debug 2 \"  setup_meta(before): $ATTR=\${$ATTR:-} (\${$ATTR[$ACTIVITY]:-})\"
        case \${$ATTR:-} in
            [0-9]*) [[ \${$ATTR[$ACTIVITY]:-} -le \${$ATTR:-} ]] || $ATTR=\"\${$ATTR[$ACTIVITY]}\" ;;
            y|n) if [[ \${ATTR[$ACTIVITY]:-} != n ]] ; then
                    $ATTR=y
               fi;;
            *cannot*) >/dev/null ;;
            *Required*) if [[ \${$ATTR} =~ \"$VMNOTOKAY\" ]] ; then
                           $ATTR=\"\${$ATTR[$ACTIVITY]}\"
                       fi;;
            *Recommended*) if [[ \${$ATTR} =~ \"$REQUIRED\" || \${$ATTR} =~ \"$VMNOTOKAY\" ]] ; then
                               $ATTR=\"\${$ATTR[$ACTIVITY]}\"
                           fi;;
            *Discouraged*) $ATTR=\"\${$ATTR[$ACTIVITY]}\" ;;
            Linux*|*MacOS*|*Windows*) if [[ \${ATTR[$ACTIVITY]:-} == Linux ]] ; then
                                           $ATTR=Linux
                                       fi ;;
            x86*|aarch64|arm|mips|powerpc|riscv)
                if [[ -n \${$ATTR[$ACTIVITY]:-} ]] ; then
                    $ATTR=\"\${$ATTR[$ACTIVITY]:-}\"
                fi ;;
            '') if [[ \${$ATTR[$ACTIVITY]:-} == - ]] ; then
                    unset $ATTR[$ACTIVITY]
                elif [[ -n \${$ATTR[$ACTIVITY]:-} ]] ; then
                    $ATTR=\"\${$ATTR[$ACTIVITY]:-}\"
                fi ;;
            *)  if [[ -n \${$ATTR[$ACTIVITY]:-} && \${$ATTR} != \${$ATTR[$ACTIVITY]:-} ]] ; then
                    $ATTR=\"\${$ATTR} \${$ATTR[$ACTIVITY]}\"
                fi ;;
        esac
        debug 2 \"  setup_meta(after): $ATTR=\${$ATTR:-} (\${$ATTR[$ACTIVITY]:-})\""
        if [[ ${ATTR:-} = OS && -n ${OS[$ATTR]:-} && ! ${OS[$ATTR]:-} =~ Linux ]] ; then
                break
        fi
        if [[ ${ATTR:-} == DISTROS ]] ; then
            # shellcheck disable=SC2086
            DISTROS[$ACTIVITY]="$(fix_distro_alias ${DISTROS[$ACTIVITY]:-})"
        fi
    done
}

#===============================================================================
[[ -n $COURSE ]] || usage
# shellcheck disable=SC2086
debug 1 "main: Final classes: "$COURSE
# shellcheck disable=SC2086
for_each_activity setup_meta $COURSE

#===============================================================================
if [[ -n $CHECK_WEB ]] ; then
    # shellcheck disable=SC2086
    debug 1 "Check Webpages for "$COURSE
    PROGRESS=y
    # shellcheck disable=SC2086
    check_webpage $COURSE
    echo
    exit 0
fi

#===============================================================================
if [[ -n $CHECK_PKGS ]] ; then
    # shellcheck disable=SC2086
    debug 1 "Check Packages for "$COURSE
    PROGRESS=y
    # shellcheck disable=SC2086
    check_packages $COURSE
    exit 0
fi

#===============================================================================
if [[ -n $LIST_PKGS ]] ; then
    debug 1 "List Packages for $COURSE => $PKGS"
    # shellcheck disable=SC2086
    for_each_activity list_packages $COURSE | sort -k2
    exit 0
fi

#===============================================================================
# List information
list_entry() {
    local NAME=$1; shift
    [[ -z "$*" ]] || echo "    $NAME: $*"
}
list_array() {
    local NAME=$1; shift
    local WS=$1; shift
    local LIST=$*
    [[ -z $LIST ]] || echo "    $WS$NAME: $LIST"
}
#-------------------------------------------------------------------------------
# shellcheck disable=SC2086 
list_requirements() {
    local ACTIVITY A DISTS DIST
    ACTIVITY=$(strip_versions "$@")
    [[ -z $ACTIVITY ]] || for_each_activity supported_activity "$ACTIVITY"
    # shellcheck disable=SC2086
    if [[ -n $ACTIVITY ]] ; then
        ACTIVITIES="$ACTIVITY"
    else
        ACTIVITIES=$(list_sort ${!TITLE[*]})
    fi
    debug 1 "list_requirements: ACTIVITY=$ACTIVITY ACTIVITIES=$ACTIVITIES"
    echo 'Courses:'
    for A in $ACTIVITIES; do
        echo "  $A:"
        list_entry TITLE "${TITLE[$A]}"
        list_entry WEBPAGE "${WEBPAGE[$A]:-}"
        list_entry INPERSON "${INPERSON[$A]:-}"
        list_entry VIRTUAL "${VIRTUAL[$A]:-}"
        list_entry SELFPACED "${SELFPACED[$A]:-}"
        list_entry EMBEDDED "${EMBEDDED[$A]:-}"
        list_entry MOOC "${MOOC[$A]:-}"
        list_entry INSTR_LED_CLASS "${INSTR_LED_CLASS[$A]:-}"
        list_entry SELFPACED_CLASS "${SELFPACED_CLASS[$A]:-}"
        list_entry PREREQ "${PREREQ[$A]:-}"
        list_entry OS "$(value OS $A)"
        list_entry OS_NEEDS "$(value OS_NEEDS $A)"
        list_entry ARCH "$(value ARCH $A)"
        list_entry CPUFLAGS "$(value CPUFLAGS $A)"
        list_entry CPUS "$(value CPUS $A)"
        list_entry PREFER_CPUS "$(value PREFER_CPUS $A)"
        list_entry BOGOMIPS "$(value BOGOMIPS $A)"
        list_entry RAM "$(value RAM $A)"
        list_entry DISK "$(value DISK $A)"
        list_entry BOOT "$(value BOOT $A)"
        list_entry CONFIGS "$(value CONFIGS $A)"
        list_entry INTERNET "$(value INTERNET $A)"
        list_entry SYMLINKS "$(value SYMLINKS $A)"
        list_entry VERSIONS "$(value VERSIONS $A)"
        #list_entry INCLUDES "$(value INCLUDES $A)"
        list_entry NATIVELINUX "$(value NATIVELINUX $A)"
        list_entry VMOKAY "$(value VMOKAY $A)"
        list_entry DISTRO_ARCH "$(value DISTRO_ARCH $A)"
        list_entry DISTRO_DEFAULT "$(value DISTRO_DEFAULT $A)"
        list_array DISTROS "" "$(value DISTROS $A)"
        # shellcheck disable=SC2086
        list_array DISTRO_BL "" "$(value DISTRO_BL $A)"
        if [[ -z $DIST_LIST ]] ; then
            DISTS=$(distrib_list)
        else
            DISTS=$DIST_LIST
        fi
        # shellcheck disable=SC2086
        debug 2 "list_requirements: DISTS="$DISTS
        if [[ -n $DISTS ]] ; then
            echo '    PACKAGES:'
            for DIST in $DISTS; do
                local P
                # shellcheck disable=SC2086
                P=$(package_list ${DIST/-/ } $A)
                # shellcheck disable=SC2086
                debug 2 "list_requirements: package list =" $P
                # shellcheck disable=SC2086
                list_array "$DIST" "  " $P
            done
        fi
    done
}

#===============================================================================
if [[ -n $LIST_REQS ]] ; then
    debug 1 "List Requirements for $COURSE"
    # shellcheck disable=SC2086
    list_requirements $COURSE
    exit 0
fi


if [[ $OS =~ Linux ]] ; then
    #===========================================================================
    # shellcheck disable=SC2086
    for_each_activity check_activity $ORIG_COURSE

    #===========================================================================
    # Check all the things
    divider "Check"
    cache_output "$COURSE" check_all
else
    warn "This course doesn't use $CMDNAME"
    exit 0
fi

#===============================================================================
# Check package list
divider "Packages"
if [[ -n $INSTALL || -z $NOINSTALL ]] ; then
    check_sudo "$ID" "$RELEASE"
    check_repos "$ID" "$RELEASE" "$CODENAME" "$ARCH"
    # shellcheck disable=SC2086
    PKGLIST=$(for_each_activity "package_list $ID $RELEASE" $COURSE)
    # shellcheck disable=SC2086
    try_packages "$ID" "$RELEASE" "$COURSE" $PKGLIST
else
    notice "Not checking whether the appropriate packages are being installed"
fi


LFT="$HOME/LFT"

#===============================================================================
get_activity_tarball() {
    local ACTIVITY=$1
    local FILE=$2
    local TODIR=$3
    local PARTIAL=n
    debug 1 "get_activity_tarball: ACTIVITY=$ACTIVITY FILE=$FILE TODIR=$TODIR PARTIAL=$PARTIAL"

    if [[ -n $NONETWORK ]] ; then
        warn "get_activity_tarball: Can't get activity tarball because no-network selected."
        return 0
    fi

    [[ -n $FILE ]] || return 0
    verbose "Get Activity File: $FILE"
    [[ -d $TODIR ]] || mkdir -p "$TODIR"
    if [[ -n $FORCEDLOAD ]] ; then
        rm -f "$TODIR/$FILE"
    elif [[ -f $TODIR/$FILE ]] ; then
        notice "Verifying $FILE..."
        if [[ -n $SIMULATE_FAILURE ]] || ! tar -t -f "$TODIR/$FILE" >/dev/null 2>&1 ; then
            warn_wait "Partial download of $TODIR/$FILE found." || return 0
            PARTIAL=y
        elif [[ -z $NOCACHE ]] && check_md5sum "$ACTIVITY" "$FILE" "$TODIR" ; then
            highlight "$FILE can be found in $TODIR (matches md5sum)"
            return 0
        else
            warn "$FILE failed md5sum check. Redownload..."
            rm -f "$TODIR/$FILE"
        fi
    else
        warn_wait "Download activity tarball? ($FILE)" || return 0
    fi
    highlight "Downloading $FILE to $TODIR"
    RETRY=1 get_file "$ACTIVITY" "$FILE" "$TODIR" "$PARTIAL"
}

#===============================================================================
# Get extra files (in sub-directories called something like LFD460_V2.0.2)
get_activity_extras() {
    local ACTIVITY=$1
    local VER=$2
    local TODIR=$3
    debug 1 "get_activity_extras: ACTIVITY=$ACTIVITY VER=$VER TODIR=$TODIR"
    local EXTRA_FILES EXTRA_FILE

    if [[ -n $NONETWORK ]] ; then
        warn "get_activity_extras: Can't get activity extras because no-network selected."
        return 0
    fi

    EXTRA_FILES=$(sed -re "s/%COURSE_VERSION%/$VER/" <<<"${EXTRAS[$ACTIVITY]:-}")
    debug 2 "   get_activity_extras: EXTRA_FILES=$EXTRA_FILES"
    if [[ -n $EXTRA_FILES ]] ; then
        verbose "Extras Files: $EXTRA_FILES"
        #warn_wait "Download extra materials? ($EXTRA_FILES)" || return 0
        for EXTRA_FILE in $EXTRA_FILES ; do
            verbose "Consider extra $EXTRA_FILE"
            case $EXTRA_FILE in
                */) mkdir -p "$TODIR/$EXTRA_FILE"
                    local ALLFILES FILE FILES
                    debug 2 "   get_activity_extras dir: EXTRA_FILES=$EXTRA_FILES"
                    ALLFILES=$(get_file "$ACTIVITY/$EXTRA_FILE" \
                            | awk -F\" '/<td>/ {print $8}')
                    debug 2 "  get_activity_extras: ALLFILES=$ALLFILES"
                    for FILE in $ALLFILES ; do
                        if try_file "$ACTIVITY/$EXTRA_FILE" "$FILE" "$TODIR/$EXTRA_FILE" ; then
                            debug 2 "  get_activity_extras: $EXTRA_FILE"
                            FILES+="$FILE "
                        fi
                    done
                    debug 2 "  Get files: $FILES"
                    if [[ -n $FILES ]] && warn_wait "Download extra materials? ($FILES)" ; then
                        for FILE in $FILES ; do
                            RETRY=1 get_file "$ACTIVITY/$EXTRA_FILE" "$FILE" "$TODIR/$EXTRA_FILE"
                        done
                    fi
                    ;;
                *)  local DIR
                    debug 2 "   get_activity_extras file: EXTRA_FILES=$EXTRA_FILES"
                    DIR=$(dirname "$TODIR/$EXTRA_FILE")
                    mkdir -p "$DIR"
                    if try_file "$ACTIVITY" "$EXTRA_FILE" "$TODIR" ; then
                        if warn_wait "Download $EXTRA_FILE?" ; then
                            debug 2 "  get_activity_extras: $EXTRA_FILE"
                            RETRY=1 get_file "$ACTIVITY" "$EXTRA_FILE" "$TODIR"
                        fi
                    fi ;;
            esac
        done
    fi
}

#===============================================================================
get_activity_files() {
    local ACTIVITY ACTVER
    IFS=":" read -r ACTIVITY ACTVER <<<"$1"
    ACTVER="${ACTVER^^}"
    local TODIR=${CMDIR:-$LFT}
    debug 1 "get_activity_files: ACTIVITY=$ACTIVITY ACTVER=$ACTVER TODIR=$TODIR"

    case "$ACTIVITY" in 
        ${ACTIVITYPAT}[12]*) return ;;
    esac

    if [[ -n $NONETWORK ]] ; then
        warn "  get_activity_files: Can't get activity files because no-network selected."
        return 0
    fi

    local FOUND='' SOLUTIONS VER RESOURCES VER2 FORCED_VER
    FORCED_VER=$(get_var VER "$ACTIVITY")
    if [[ -n $FORCED_VER ]] ; then
        VER="$FORCED_VER"
    elif [[ -n $ACTVER ]] ; then
        VER="$ACTVER"
    elif [[ -n $CVER ]] ; then
        VER="$CVER"
    fi
    debug 1 "  get_activity_files: ACTIVITY=$ACTIVITY VER=$VER TODIR=$TODIR"

    # shellcheck disable=SC2046
    read -r SOLUTIONS VER <<< $(get_activity_file "$ACTIVITY" SOLUTIONS "$VER")
    # shellcheck disable=SC2046
    read -r RESOURCES VER2 <<< $(get_activity_file "$ACTIVITY" RESOURCES "$VER")
    debug 1 "  get_activity_files: SOLUTIONS=$SOLUTIONS RESOURCES=$RESOURCES"
    [[ -n $VER ]] || VER=$VER2
    local FORCED_SOLUTIONS FORCED_RESOURCES
    FORCED_SOLUTIONS=$(get_var SOLUTIONS "$ACTIVITY")
    [[ -z $FORCED_SOLUTIONS ]] || SOLUTIONS="$FORCED_SOLUTIONS"
    FORCED_RESOURCES=$(get_var RESOURCES "$ACTIVITY")
    [[ -z $FORCED_RESOURCES ]] || RESOURCES="$FORCED_RESOURCES"
    debug 2 "   get_activity_files: VER=$VER SOLUTIONS=$SOLUTIONS RESOURCES=$RESOURCES"

    if [[ -n $SOLUTIONS ]] ; then
        FOUND=y
        verbose "Get solutions for $ACTIVITY"
        get_activity_tarball "$ACTIVITY" "$SOLUTIONS" "$TODIR"
        verbose "Check for $ACTIVITY errata..."
        get_file "$ACTIVITY" "${ACTIVITY}_${VER}_ERRATA.txt" "$TODIR"
    fi
    debug 2 "   get_activity_files: FOUND=$FOUND"
    debug 2 "   get_activity_files: check RESOURCES=$RESOURCES"
    if [[ -n $RESOURCES ]] ; then
        FOUND=y
        verbose "Get resources for $ACTIVITY"
        get_activity_tarball "$ACTIVITY" "$RESOURCES" "$TODIR"
    fi
    debug 2 "   get_activity_files: FOUND=$FOUND"
    if [[ -z $FOUND ]] ; then
        notice "No activity files for $ACTIVITY"
    fi
    [[ -n $NOEXTRAS ]] || get_activity_extras "$ACTIVITY" "$VER" "$TODIR"
}

#===============================================================================
get_all_activity_files() {
    debug 1 "get_all_activity_files: $*"

    if [[ -n $NONETWORK ]] ; then
        warn "get_all_activity_files: Can't get all activity files because no-network selected."
        return 0
    fi

    local ACTIVITY ACTVER CMS CM ACTIVITIES
    for ACTIVITY in "$@"; do
        IFS="=" read -r ACTIVITY ACTVER <<<"$ACTIVITY"
        case "$ACTIVITY" in 
            ${ACTIVITYPAT}[12]*) continue ;;
        esac

        if CM=$(get_var CM "$ACTIVITY") && [[ -n $CM ]] ; then
            CMS+="$CM${ACTVER:+:$ACTVER} "
        elif ACTIVITIES=$(get_var COURSES "$ACTIVITY") && [[ -n $ACTIVITIES ]] ; then
            CMS+="$ACTIVITIES "
        else
            CMS+="$ACTIVITY${ACTVER:+:$ACTVER} "
        fi
    done
    debug 1 "Install activity files for: $* as $CMS"
    # shellcheck disable=SC2086
    for_each_activity get_activity_files $CMS
}

#===============================================================================
if [[ -z $NOCM ]] ; then
    divider "Materials"
    # shellcheck disable=SC2086
    get_all_activity_files $ORIG_COURSE
fi


#===============================================================================
# Get Suggested VM for class
get_virtual_machine() {
    [[ -n $VMS ]] || return 0
    debug 1 "get_virtual_machine: VMS=$VMS"
    declare LIST
    read -r -a LIST <<<"$VMS"

    local VM
    VM="${VMS// /|}"
    ask "Which VM would you like to download? [None|$VM]"
    read -r VM
    case $VM in
        0|n*|N*) return;;
        [1-9]*) VM=$((VM - 1)); VM="${LIST[$VM]}";;
        *) VM="${LIST[0]}";;
    esac
    local FILE="$VM.tar.gz"
    notice "Downloading: $FILE"
    get_file "$VMURL" "$FILE" "$LFT"
}

#===============================================================================
if [[ -z $NOVM ]] ; then
    # shellcheck disable=SC2086
    get_virtual_machine
fi


#===============================================================================
# Overall PASS/FAIL
divider "Result"
if [[ -n $FAILED ]] ; then
    warn "You will likely have troubles using this computer as configured with this course. Ask your instructor about this."
elif [[ -n $WARNINGS ]] ; then
    warn "You may have troubles using this computer for this course unless you can fix the above warnings."
    if [[ -n $MISSING_PACKAGES ]] ; then
        warn "You also have some missing packages, which ideally need installing before class."
    fi
    warn "Ask your instructor on the day of the course if you have more questions."
else
    pass "You are ready for the course! W00t!"
fi


#===============================================================================
# Clean up and exit
clean_cache

notice "Make sure to follow the instructions above to fix any issues found"

exit 0

