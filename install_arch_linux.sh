#!/bin/bash
#===============================================================================
#
#          FILE: install_arch_linux.sh
#
#         USAGE: ./install_arch_linux.sh [-hvlr] [-L logfile] [-c configfile] [-d device]
#
#   DESCRIPTION: Bash script for installing Arch Linux. This script follows the
#                Arch Linux installation guide (https://wiki.archlinux.org).
#
#       OPTIONS:
#                  -h               prints this help menu to stdout
#                  -v               prints detailed output to stdout
#                  -l               prints detailed output to logfile (standard logfile)
#                  -L <logfile>     prints detailed output to logfile <filename>
#                  -r               if -l or -L is selected and the logfile allready exists,
#                                   the existing logfile will be removed (standard is to append
#                                   to existing logfile)
#                  -c <configfile>  preselect a configfile (standard is a select menu)
#                  -d <device>      preselect a target disk <device>
#
#  REQUIREMENTS: This script assumes familiarity with Arch Linux installation
#                and requires an active internet connection. Read the README.md for more information.
#
#       WARNING: Disk Encryption and Data Deletion: This script will encrypt the
#                target disk, and all existing data on the disk will be permanently
#                deleted during the installation process. Ensure you have backed up
#                any important data before running the script.
#
#                Be careful and make sure you know what you are doing. This script
#                and the configuration file do not replace reading and understanding
#                the official documentation.
#
# DOCUMENTATION: For more detailed information, please refer to the README.md:
#                https://github.com/dominikoetiker/ArchLinuxInstaller/blob/main/README.md
#
#
#        AUTHOR: Dominik Oetiker
#       CREATED: April 27, 2022
#       LICENSE: MIT
#    REPOSITORY: https://github.com/dominikoetiker/ArchLinuxInstaller
#
#===============================================================================

abort() {
	#-----------------------------------------------------------------------
	# output error message and exit programm
	#-----------------------------------------------------------------------
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf "ERROR: %b\n" "$1" | tee -a $LOG_FILE >>/dev/stderr
	else
		printf "ERROR: %b\n" "$1" >>/dev/stderr
	fi
	exit 1
}

abortquietly() {
	#-----------------------------------------------------------------------
	# exit programm
	#-----------------------------------------------------------------------
	exit "$1"
}

col() {
	#-----------------------------------------------------------------------
	# get the elements of a column
	# input: $1 is the section, where to find the elements
	# input: $2 is the header of the column
	# output: elements of a column
	#-----------------------------------------------------------------------
	awk -v startnr=$(rownr $1 "start") -v endnr=$(rownr $1 "end") -v column=$(colnr $1 $2) 'NR >= startnr && NR <= endnr { print $column }' $CONFIGFILE
}

colnr() {
	#-----------------------------------------------------------------------
	# get the number of a column
	# input: $1 is the section ("VARIABLES", "PARTITIONS" or "LVM")
	# input: $2 is the searchstring ("NAME", "SIZE", etc)
	# output: column number
	#-----------------------------------------------------------------------
	awk -v searchrow=$(rownr $1 "title") -v searchstring=$2 'NR == searchrow { for (i=1;i<=NF;i++) if ($i == searchstring) { print i } }' $CONFIGFILE
}

format() {
	#-----------------------------------------------------------------------
	# formats partitions or logical volumes with filesystems
	# input: $1 is the searchname for the target
	# input: $2 is the range of the target
	# output: command execution and printing (make file systems commands)
	#-----------------------------------------------------------------------
	if [[ "$(value $1 NAME FILESYS $2)" != "n/a" ]]; then
		if [[ "$(value $1 NAME FILESYS $2)" == "fat32" ]]; then
			local FORMATCOMMAND="mkfs.fat -F32"
		fi
		if [[ "$(value $1 NAME FILESYS $2)" == "ext4" ]]; then
			local FORMATCOMMAND="mkfs.ext4 -q"
		fi
		if [[ "$(value $1 NAME FILESYS $2)" == "swap" ]]; then
			local FORMATCOMMAND="mkswap"
		fi
		if [[ "$2" == "PARTITIONS" ]]; then
			local TARGETPATH="${TARGET_DISK}${PART_SUFFIX}$(value $1 NAME PARTNR $2)"
		fi
		if [[ "$2" == "LVM" ]]; then
			local TARGETPATH="/dev/$LVM_VG_NAME/$1"
		fi
		runcommand "$FORMATCOMMAND $TARGETPATH"
	fi
}

mainsteptitle() {
	#-----------------------------------------------------------------------
	# outputs title of main steps including the url to the step in the installation guide
	#-----------------------------------------------------------------------
	printline "-"
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf "%s\n" "$1" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf "%s\n" "${BOLD}$1${NORMAL}"
	fi
	printurl "$2"
	printline "-"
}

printline() {
	#-----------------------------------------------------------------------
	# prints a line full of one character / symbol
	# prints line to stdout or logfile or both
	#-----------------------------------------------------------------------
	printf -v LINECHAR "%c" "$1"
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf '%*s\n' $LOG_FILE_WIDTH '' | tr ' ' "$LINECHAR" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf '%*s\n' $(tput cols) '' | tr ' ' "$LINECHAR"
	fi
}

printlogstdout() {
	#-----------------------------------------------------------------------
	# outputs message or prevents output.
	# messages are output to stdout or logfile or both
	#-----------------------------------------------------------------------
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf "%b\n" "$1" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf "%b\n" "$1"
	fi
}

printstatus() {
	#-----------------------------------------------------------------------
	# outputs status message to end of the line with the command
	# message is output to stdout or logfile or both or none
	#-----------------------------------------------------------------------
	local STATUSWIDTH=5
	printf -v COLORSTATUS "[ ${BOLD}$2%-*b${NORMAL}]" "$STATUSWIDTH" "$1"
	printf -v PURESTATUS "[ %-*b]" "$STATUSWIDTH" "$1"
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf '%*b\n' "$(($LOG_FILE_WIDTH - ${#COMMANDTEXT}))" "$PURESTATUS" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf '%*b\n' "$(($(tput cols) - ${#PUREPROMPTCOMMANDTEXT} + ${#COLORSTATUS} - ${#PURESTATUS}))" "$COLORSTATUS"
	fi
}

printurl() {
	#-----------------------------------------------------------------------
	# input $1 url
	# output printed url to stdout or logfile or both or none
	#-----------------------------------------------------------------------
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf "%s\n" "[$1]" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf "%s\n" "[${FOREGROUND_CYAN}$1${NORMAL}]"
	fi
}

rownr() {
	#-----------------------------------------------------------------------
	# get the row number
	# input: $1 is the searchstring
	# input: $2 is either "title", "start" or "end"
	# output: row number
	#-----------------------------------------------------------------------
	if [[ $2 == "end" ]]; then
		i=$(awk -v searchstring="[$1]" '$0 == searchstring { print NR }' $CONFIGFILE)
		while [[ -n $(awk -v linenumber=$i 'NR == linenumber { print $0 }' $CONFIGFILE) ]]; do
			let "i++"
		done
		printf $i
	else
		awk -v searchstring="[$1]" -v pos=$2 '$0 == searchstring { if (pos == "title") { print NR+1 } else if (pos == "start") { print NR+2 } }' $CONFIGFILE
	fi
}

runcommand() {
	#-----------------------------------------------------------------------
	# handels running main commands.
	# this includes to print out status messages, error messages and/or exit script
	#-----------------------------------------------------------------------
	if [[ -n $2 ]]; then
		local PRINTOUTCOMMAND="$2"
	else
		local PRINTOUTCOMMAND="$1"
	fi
	printf -v COLORPROMPTCOMMANDTEXT "$BOLD$FOREGROUND_RED$FAKE_TERMINAL_PROMPT$NORMAL%s" "$PRINTOUTCOMMAND"
	printf -v PUREPROMPTCOMMANDTEXT "$FAKE_TERMINAL_PROMPT%s" "$PRINTOUTCOMMAND"
	printf -v COMMANDTEXT "%s" "$PRINTOUTCOMMAND"
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf '%s' "$COMMANDTEXT" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf '%s' "$COLORPROMPTCOMMANDTEXT"
	fi
	$($1 >/dev/null 2>&1)
	local EXITCODE=$?
	if [[ $EXITCODE -gt 0 ]]; then
		printstatus "FAIL" "$FOREGROUND_RED"
		abort "command '$PRINTOUTCOMMAND' returns exit code $EXITCODE"
	else
		printstatus "DONE" "$FOREGROUND_GREEN"
	fi
}

setpassphrase() {
	#-----------------------------------------------------------------------
	# sets a passphrase and stores it in a variable
	#-----------------------------------------------------------------------
	i=0
	while [[ $i -lt 2 ]]; do
		i=0
		read -s -p "${BOLD}${FOREGROUND_YELLOW}enter passphrase for $1${NORMAL} " PW
		if [[ ! -n "$PW" ]]; then
			printf "\n%s\n" "ERROR: passphrase can not be empty, try again"
		else
			let "i++"
			printf "\n"
			read -s -p "${BOLD}${FOREGROUND_YELLOW}enter passphrase again to verify${NORMAL} " PW_VERIFY
			if [[ $PW = $PW_VERIFY ]]; then
				let "i++"
				printf "\n"
			else
				printf "\n%s\n" "ERROR: passphrases do not match, try again"
			fi
		fi
	done
	export ${2}=$PW
	unset PW
	unset PW_VERIFY
}

substeptitle() {
	#-----------------------------------------------------------------------
	# outputs title of sub steps
	#-----------------------------------------------------------------------
	printline "."
	printlogstdout "$1"
	printurl "$2"
	printline "."
}

usage() {
	#-----------------------------------------------------------------------
	# prints message, how to correctly use options
	#-----------------------------------------------------------------------
	cat <<EOF
$0	script to install arch linux
following official installation guide:
[https://wiki.archlinux.org/title/Installation_guide]
usage: $0 [-hvlr] [-L logfile] [-c configfile] [-d device]

  -h			prints this help menu to stdout
  -v			prints detailed output to stdout
  -l			prints detailed output to logfile (standard logfile)
  -L <logfile>		prints detailed output to logfile <filename>
  -r			if -l or -L is selected and the logfile allready exists,
			the existing logfile will be removed (standard is to append
			to existing logfile)
  -c <configfile>	preselect a configfile (standard is a select menu)
  -d <device>		preselect a target disk <device>
EOF
}

userinteractiontitle() {
	#-----------------------------------------------------------------------
	# outputs title for a interactive section to stdout
	#-----------------------------------------------------------------------
	printf -v USER_INTERACTION_TITLE '%s' "$1"
	printf "$BOLD$FOREGROUND_YELLOW%*s$NORMAL\n" ${#USER_INTERACTION_TITLE} '' | tr ' ' '-'
	printf "$BOLD$FOREGROUND_YELLOW%s$NORMAL\n" "$USER_INTERACTION_TITLE"
	printf "$BOLD$FOREGROUND_YELLOW%*s$NORMAL\n" ${#USER_INTERACTION_TITLE} '' | tr ' ' '-'
}

value() {
	#-----------------------------------------------------------------------
	# get a value from configfile
	# input: $1 is the searchstring
	# input: $2 is the title of the column, where the searchstring shold be found
	# input: $3 is the title of the column, where the result should be found
	# input: $4 is the name of the range, where the result is
	# output: the value, that results from the search
	#-----------------------------------------------------------------------
	awk -v startnr=$(rownr $4 "start") -v endnr=$(rownr $4 "end") -v searchcol=$(colnr $4 $2) -v searchstring=$1 -v resultcol=$(colnr $4 $3) 'NR >= startnr && NR <= endnr && $searchcol == searchstring {print $resultcol}' $CONFIGFILE
}

warning() {
	#-----------------------------------------------------------------------
	# prints a warning and let user decide what to do
	#-----------------------------------------------------------------------
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf '%*s\n' $LOG_FILE_WIDTH '' | tr ' ' "!" >>$LOG_FILE
		printf "%s\n" "!!! WARNING !!!" >>$LOG_FILE
		printf "%s\n" "$1" >>$LOG_FILE
		printf '%*s\n' $LOG_FILE_WIDTH '' | tr ' ' "!" >>$LOG_FILE
	fi
	printf "${FOREGROUND_RED}${BOLD}%*s\n${NORMAL}" $(tput cols) '' | tr ' ' "!"
	printf "${FOREGROUND_RED}${BOLD}%s\n${NORMAL}" "!!! WARNING !!!"
	printf "${FOREGROUND_RED}${BOLD}%s\n${NORMAL}" "$1"
	printf "${FOREGROUND_RED}${BOLD}%*s\n${NORMAL}" $(tput cols) '' | tr ' ' "!"
	read -p "${FOREGROUND_YELLOW}${BOLD}if you want to continue, type 'YES' in all caps: ${NORMAL}" ANSWER
	if [[ $ANSWER != "YES" ]]; then
		abort "instead of 'YES', you typed '$ANSWER', abort installation"
	fi
}

setmetavariables() {
	#-----------------------------------------------------------------------
	# set the meta variables for this script
	#-----------------------------------------------------------------------
	#  - ${PRINT_OUTPUT_LOGFILE} condition whether the output is logged or not (true/false)
	if [[ -z $PRINT_OUTPUT_LOGFILE ]]; then
		PRINT_OUTPUT_LOGFILE=false
	fi
	#  - ${LOG_APPEND} condition whether to append to or replace existing log (true/false)
	if [[ -z $LOG_APPEND ]]; then
		LOG_APPEND=true
	fi
	#  - ${PRINT_OUTPUT_STDOUT} condition whether to print the output to stdout or not (true/false)
	if [[ -z $PRINT_OUTPUT_STDOUT ]]; then
		PRINT_OUTPUT_STDOUT=false
	fi
	#  - ${LOG_FILE} name of the logfile
	if [[ -z $LOG_FILE ]]; then
		LOG_FILE=logfile.log
	fi
	#  - ${LOG_FILE_WIDTH} number of characters of one line of the logfile
	LOG_FILE_WIDTH=90
	#  - ${NORMAL} standard output format
	NORMAL=$(tput sgr0)
	#  - ${BOLD} bold output format of text
	BOLD=$(tput bold)
	#  - ${FOREGROUND_BLUE} blue output format of text
	FOREGROUND_BLUE=$(tput setaf 4)
	#  - ${FOREGROUND_RED} red output format of text
	FOREGROUND_RED=$(tput setaf 1)
	#  - ${FOREGROUND_GREEN} green output format of text
	FOREGROUND_GREEN=$(tput setaf 2)
	#  - ${FOREGROUND_YELLOW} yellow output format of text
	FOREGROUND_YELLOW=$(tput setaf 3)
	#  - ${FOREGROUND_CYAN} cyan output format of text
	FOREGROUND_CYAN=$(tput setaf 6)
	#  - ${FOREGROUND_MAGENTA} cyan output format of text
	FOREGROUND_MAGENTA=$(tput setaf 5)
	#  - ${FAKE_TERMINAL_PROMPT} fake terminal prompt for printed comands
	FAKE_TERMINAL_PROMPT=">_ # "
}

setvariables() {
	#-----------------------------------------------------------------------
	# set the variables
	#-----------------------------------------------------------------------
	#  - ${CONFIGFILE} file name of the config file, that should be used
	if [[ -z $CONFIGFILE ]]; then
		userinteractiontitle "chose a profile:"
		mapfile -t configtitles < <(awk 'BEGIN { FS="\t+" } FNR == 1 && $1 == "CONFIGNAME" { print $2 }' config* | uniq)
		PS3="${BOLD}${FOREGROUND_YELLOW}your choice? ${NORMAL}"
		printf "${FOREGROUND_BLUE}NR %s${NORMAL}\n" PROFILE
		COLUMNS=1
		select CONFIGTITLE in "${configtitles[@]}"; do
			CONFIGFILE=$(awk -v configtitle="$CONFIGTITLE" 'BEGIN { FS="\t+" } FNR == 1 && $2 == configtitle { print FILENAME }' config*)
			if [[ $(awk -v configtitle="$CONFIGTITLE" 'BEGIN { FS="\t+" } FNR == 1 && $2 == configtitle { print FILENAME }' config* | wc -l) -gt 1 ]]; then
				abort "there exist multiple config files with the title $CONFIGTITLE:\n$(awk -v configtitle="$CONFIGTITLE" 'BEGIN { FS="\t+" } FNR ==  1 && $2 == configtitle { print FILENAME }' config*)"
			fi
			break
		done
	fi
	#  - ${KEYMAP} name of the keymap
	if [[ ! $(value "KEYMAP" "VARIABLE" "VALUE" "OPTIONAL_VARIABLES") == "" ]]; then
		KEYMAP=$(value "KEYMAP" "VARIABLE" "VALUE" "OPTIONAL_VARIABLES")
	else
		i=0
		while [[ $i -eq 0 ]]; do
			userinteractiontitle "search keymap by searchstring: "
			read -p "${BOLD}${FOREGROUND_YELLOW}searchterm to search for keymap: ${NORMAL}" SEARCHTERM
			userinteractiontitle "chose a keymap from searchresults: "
			variables=($(find /usr/share/kbd/keymaps/ -iname '*.map.gz' | awk 'BEGIN { FS="/" } { print $(NF) }' | awk 'BEGIN { FS="."} {print $1 }' | less | grep -i $SEARCHTERM) "new search")
			PS3="${BOLD}${FOREGROUND_YELLOW}your choice? ${NORMAL}"
			printf "${FOREGROUND_BLUE}NR %s${NORMAL}\n" KEYMAP
			COLUMNS=1
			select KEYMAP in "${variables[@]}"; do
				if [[ "$KEYMAP" != "new search" ]]; then
					((i++))
					break
				else
					break
				fi
			done
		done
	fi
	#  - ${TARGET_DISK} path of the targetdisk
	if [[ -z $TARGET_DISK ]]; then
		userinteractiontitle "choose a target disk: "
		printf "${FOREGROUND_BLUE}NR %-20s%-10s%s${NORMAL}\n" NAME SIZE MODEL
		mapfile -t disks < <(lsblk -lpno NAME,SIZE,TYPE,MODEL | awk '$3 = /disk/ {printf "%-20s%-10s%s\n", $1, $2, $4}')
		PS3="${BOLD}${FOREGROUND_YELLOW}your choice? ${NORMAL}"
		COLUMNS=1
		select TARGET_DISK in "${disks[@]}"; do
			TARGET_DISK=$(printf "$TARGET_DISK" | awk '{print $1}')
			break
		done
	fi
	#  - ${PART_SUFFIX} Suffix for nvme-disk ("p")
	if [[ $(printf $TARGET_DISK | awk 'BEGIN { FS="/" } {printf "%.4s", $NF}') == "nvme" ]]; then
		PART_SUFFIX="p"
	else
		PART_SUFFIX=""
	fi
	#  - ${CRYPT_PART} path of the encrypted partition
	local CRYPT_PART_NR=$(value "crypt-partition" "NAME" "PARTNR" "PARTITIONS")
	CRYPT_PART=${TARGET_DISK}${PART_SUFFIX}${CRYPT_PART_NR}
	#  - ${CRYPT_MAPPER_NAME} name for the mapper to map the cryptcontainer to
	CRYPT_MAPPER_NAME=$(value "CRYPT_MAPPER_NAME" "VARIABLE" "VALUE" "VARIABLES")
	#  - ${LVM_VG_NAME} name of the volume group
	LVM_VG_NAME=$(value "LVM_VG_NAME" "VARIABLE" "VALUE" "VARIABLES")
	#  - ${MIRROR_COUNTRIES} countries, to get mirrors from into mirrorlist
	MIRROR_COUNTRIES=$(value "MIRROR_COUNTRIES" "VARIABLE" "VALUE" "VARIABLES")
	#  - ${TIME_ZONE} last part of the path to the time zone
	if [[ ! $(value "TIME_ZONE" "VARIABLE" "VALUE" "OPTIONAL_VARIABLES") == "" ]]; then
		TIME_ZONE=$(value "TIME_ZONE" "VARIABLE" "VALUE" "OPTIONAL_VARIABLES")
	else
		i=0
		while [[ $i -eq 0 ]]; do
			userinteractiontitle "search location for time zone by searchstring: "
			read -p "${BOLD}${FOREGROUND_YELLOW}searchterm to search for a location for the time zone: ${NORMAL}" SEARCHTERM
			userinteractiontitle "chose a location for the time zone from searchresults: "
			variables=($(find /usr/share/zoneinfo/ -type f | sed 's/\/usr\/share\/zoneinfo\///;/\.zi/d;/\.tab/d;/^posix\//d;/^right\//d' | grep -i $SEARCHTERM) "new search")
			PS3="${BOLD}${FOREGROUND_YELLOW}your choice? ${NORMAL}"
			printf "${FOREGROUND_BLUE}NR %s${NORMAL}\n" LOCATION
			COLUMNS=1
			select TIME_ZONE in "${variables[@]}"; do
				if [[ "$TIME_ZONE" != "new search" ]]; then
					((i++))
					break
				else
					break
				fi
			done
		done
	fi
	#  - ${HOST_NAME} hostname
	HOST_NAME=$(value "HOST_NAME" "VARIABLE" "VALUE" "VARIABLES")
	#  - ${MOUNTPOINT_BOOT} mount point of boot partition
	MOUNTPOINT_BOOT=$(value "boot-partition" "NAME" "MOUNTPOINT" "PARTITIONS")
}

setarrays() {
	#-----------------------------------------------------------------------
	# set the arrays
	#-----------------------------------------------------------------------
	#  - ${partitionsnames[@]} list of all partitions
	partitionsnames=($(col "PARTITIONS" "NAME"))
	#  - ${lvmnames[@]} list of all logical volumes
	lvmnames=($(col "LVM" "NAME"))
	#  - ${sortedlvmmountpoints[@]} list of all mountpoints for lvm fs in a sorted order
	sortedlvmmountpoints=($(sort <<<"$(col LVM MOUNTPOINT)"))
	#  - ${essentialpackages[@]} list of all essential packages, that would be installed in the first installation
	essentialpackages=($(col "ESSENTIALPACKAGES" "PACKAGE"))
	#  - ${locales[@]} list of all needed locales
	locales=($(col "LOCALIZATIONS" "LOCALIZATION" | uniq))
	#  - ${localevariables[@]} list of all used localization variables
	localevariables=($(col "LOCALIZATIONS" "VARIABLE"))
	#  - ${bootloaderpackages[@]} list of all bootloader packages
	bootloaderpackages=($(col "BOOTLOADERPACKAGES" "PACKAGE"))
	#  - ${microcodepackages[@]} list of all microcode packages
	microcodepackages=($(col "MICROCODEPACKAGES" "PACKAGE"))
}

greeting() {
	#-----------------------------------------------------------------------
	# prints a nice greeting to stdout, logfile, both or none
	#-----------------------------------------------------------------------
	EXEC_DATE=$(date)
	printlogstdout ""
	printline "+"
	printlogstdout "starting at $EXEC_DATE"
	printline "+"
	PURE_SCRIPTTITLE_INSTALLING="INSTALLING "
	PURE_SCRIPTTITLE_ARCH="ARCH LINUX"
	PURE_SCRIPTTITLE="$PURE_SCRIPTTITLE_INSTALLING$PURE_SCRIPTTITLE_ARCH"
	printf -v COLOR_SCRIPTTITLE_ARCH "$BOLD$FOREGROUND_BLUE%s$NORMAL" "$PURE_SCRIPTTITLE_ARCH"
	COLOR_SCRIPTTITLE="$PURE_SCRIPTTITLE_INSTALLING$COLOR_SCRIPTTITLE_ARCH"
	TITLESTRINGDIFF="$((${#COLOR_SCRIPTTITLE} - ${#PURE_SCRIPTTITLE}))"
	COLOR_SCRIPTTITLE_INDENTION=$((${#COLOR_SCRIPTTITLE} + $TITLESTRINGDIFF))
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]]; then
		printf "%*s\n" $(((${#PURE_SCRIPTTITLE} + $LOG_FILE_WIDTH) / 2)) "$PURE_SCRIPTTITLE" >>$LOG_FILE
	fi
	if [[ "$PRINT_OUTPUT_STDOUT" == "true" ]]; then
		printf "%*s\n" $((($COLOR_SCRIPTTITLE_INDENTION + $(tput cols)) / 2)) "$PURE_SCRIPTTITLE_INSTALLING$COLOR_SCRIPTTITLE_ARCH"
	fi
	printline "="
	printlogstdout "this is a simple way of installing arch linux"
	printlogstdout "this script is going to follow the official install guide"
	printurl "https://wiki.archlinux.org/title/Installation_guide"
	printlogstdout "release date: 04/26 2022"
	printlogstdout "author: dominik oetiker"
	printline "="
}

preparingdisk() {
	#-----------------------------------------------------------------------
	# prepares the disks:
	#  - partition the disk
	#  - create and open luks encrypted container
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.1 Preparing the disk" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_disk_2"
	runcommand "parted -s $TARGET_DISK mklabel gpt"
	for i in ${partitionsnames[@]}; do
		local STARTSIZE="$(value "$i" "NAME" "STARTSIZE" "PARTITIONS")"
		local ENDSIZE="$(value "$i" "NAME" "ENDSIZE" "PARTITIONS")"
		if [[ "$(value "$i" "NAME" "FILESYS" "PARTITIONS")" == "n/a" ]]; then
			local FILESYS="ext4"
		else
			local FILESYS="$(value "$i" "NAME" "FILESYS" "PARTITIONS")"
		fi
		local FLAG="$(value "$i" "NAME" "FLAG" "PARTITIONS")"
		local PARTNR="$(value "$i" "NAME" "PARTNR" "PARTITIONS")"
		runcommand "parted -s $TARGET_DISK mkpart $i $FILESYS $STARTSIZE $ENDSIZE"
		if [[ ! $FLAG == "n/a" ]]; then
			runcommand "parted -s $TARGET_DISK set $PARTNR $FLAG"
		fi
	done
	setpassphrase "luks encrypted partition" "PW_CRYPTDISK"
	runcommand "$(printf "$PW_CRYPTDISK" | cryptsetup --batch-mode luksFormat $CRYPT_PART)" "printf \"*****\" | cryptsetup --batch-mode luksFormat $CRYPT_PART"
	runcommand "$(printf "$PW_CRYPTDISK" | cryptsetup --batch-mode open $CRYPT_PART $CRYPT_MAPPER_NAME)" "printf \"*****\" | cryptsetup --batch-mode open $CRYPT_PART $CRYPT_MAPPER_NAME"
	unset PW_CRYPTDISK
}

preparinglogicalvolumes1() {
	#-----------------------------------------------------------------------
	# prepares the logical volumes
	#  - creates a physical volume
	#  - create a volume group
	#  - creates all logical volumes
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.2 Preparing the logical volumes (I)" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_logical_volumes"
	runcommand "pvcreate -qq /dev/mapper/$CRYPT_MAPPER_NAME"
	runcommand "vgcreate -qq $LVM_VG_NAME /dev/mapper/$CRYPT_MAPPER_NAME"
	for i in ${lvmnames[@]}; do
		if [[ "$(value "$i" "NAME" "SIZE" "LVM")" != "100%FREE" ]]; then
			runcommand "lvcreate -qq -L $(value $i NAME SIZE LVM) $LVM_VG_NAME -n $i"
		fi
	done
	for i in ${lvmnames[@]}; do
		if [[ "$(value "$i" "NAME" "SIZE" "LVM")" == "100%FREE" ]]; then
			runcommand "lvcreate -qq -l $(value $i NAME SIZE LVM) $LVM_VG_NAME -n $i"
		fi
	done
}

preparinglogicalvolumes2() {
	#-----------------------------------------------------------------------
	# prepares the logical volumes
	#  - formats the logical volumes with filesystems
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.2 Preparing the logical volumes (II)" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_logical_volumes"
	for i in ${lvmnames[@]}; do
		format $i LVM
	done
}

preparingbootpart1() {
	#-----------------------------------------------------------------------
	# prepares the boot partition
	#  - formats the boot partition with filesystem
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.3 Preparing the boot partition (I)" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_boot_partition_2"
	format boot-partition PARTITIONS
}

preparinglogicalvolumes3() {
	#-----------------------------------------------------------------------
	# prepares the logical volumes
	#  - mount the filesystems on the logical volumes
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.2 Preparing the logical volumes (III)" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_logical_volumes"
	for i in ${sortedlvmmountpoints[@]}; do
		if [[ "$i" != "swap" ]]; then
			local LVM_LV_NAME="$(value $i MOUNTPOINT NAME LVM)"
			runcommand "mount -o X-mount.mkdir /dev/${LVM_VG_NAME}/$LVM_LV_NAME /mnt${i}"
		fi
	done
	for i in ${sortedlvmmountpoints[@]}; do
		if [[ "$i" == "swap" ]]; then
			local LVM_LV_NAME="$(value $i MOUNTPOINT NAME LVM)"
			runcommand "swapon /dev/${LVM_VG_NAME}/$LVM_LV_NAME"
		fi
	done
}

preparingbootpart2() {
	#-----------------------------------------------------------------------
	# prepares the boot partition
	#  - mounts the filesystem on the boot partition
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.3 Preparing the boot partition (II)" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Preparing_the_boot_partition_2"
	runcommand "mount -o X-mount.mkdir ${TARGET_DISK}${PART_SUFFIX}$(value "/boot" MOUNTPOINT PARTNR PARTITIONS) /mnt/boot"
}

localhostnameresolution() {
	#-----------------------------------------------------------------------
	# configuring the hosts file
	# makes sure, that software, that still reads from /etc/hosts, can resolve the local hostname and localhost
	#-----------------------------------------------------------------------
	substeptitle "(Network configuration:) 3.1 Local hostname resolution" "https://wiki.archlinux.org/title/Network_configuration#Local_hostname_resolution"
	runcommand "$(printf "%s\n" "127.0.0.1 localhost" >>/mnt/etc/hosts)" "printf \"%s\\n\" \"127.0.0.1 localhost\" >> /mnt/etc/hosts"
	runcommand "$(printf "%s\n" "::1 localhost" >>/mnt/etc/hosts)" "printf \"%s\\n\" \"::1 localhost\" >> /mnt/etc/hosts"
	runcommand "$(printf "%s\n" "127.0.1.1 $HOST_NAME" >>/mnt/etc/hosts)" "printf \"%s\\n\" \"127.0.1.1 $HOST_NAME\" >> /mnt/etc/hosts"
}

rundhcpcd() {
	#-----------------------------------------------------------------------
	# start the dhcpcd deamon for all network interfaces
	#-----------------------------------------------------------------------
	substeptitle "(Network configuration#DHCP: dhcpcd:) 2.Running" "https://wiki.archlinux.org/title/Dhcpcd#Running"
	runcommand "arch-chroot /mnt systemctl enable --quiet dhcpcd.service"
}

configuringmkinitcpio() {
	#-----------------------------------------------------------------------
	# add the keyboard, keymap, encrypt and lvm2 hooks to mkinitcpio.conf
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.4 Configuring mkinitcpio" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio_2"
	runcommand "$(awk -i inplace '{if ($0 ~ /^HOOKS=/) {print $1,$2,$3,"keyboard keymap consolefont",$4,$5,"encrypt lvm2",$6,$8} else {print $0}}' /mnt/etc/mkinitcpio.conf)" "awk -i inplace '{if (\$0 ~ /^HOOKS=/) {print \$1,\$2,\$3,\"keyboard keymap consolefont\",\$4,\$5,\"encrypt lvm2\",\$6,\$8} else {print \$0}}' /mnt/etc/mkinitcpio.conf"
}

grubinstallation() {
	#-----------------------------------------------------------------------
	# installs the grub boot loader
	#-----------------------------------------------------------------------
	substeptitle "(Arch boot process: 3 Boot loader: GRUB:) 2.1 Installation" "https://wiki.archlinux.org/title/GRUB#Installation_2"
	for i in ${bootloaderpackages[@]}; do
		runcommand "arch-chroot /mnt pacman -S --noconfirm --quiet --noprogressbar $i"
	done
	runcommand "$(arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=$MOUNTPOINT_BOOT --bootloader-id=GRUB &>/dev/null)" "arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=$MOUNTPOINT_BOOT --bootloader-id=GRUB &>/dev/null"
}

microcodeinstallation() {
	#-----------------------------------------------------------------------
	# installs the microcode-tool
	#-----------------------------------------------------------------------
	substeptitle "(Microcode:) 1.1 Installation" "https://wiki.archlinux.org/title/Microcode#Installation"
	for i in ${microcodepackages[@]}; do
		runcommand "arch-chroot /mnt pacman -S --noconfirm --quiet --noprogressbar $i"
	done
}

grubconfiguration() {
	#-----------------------------------------------------------------------
	# configures grub to work with encrypted disk
	#-----------------------------------------------------------------------
	substeptitle "(dm-crypt/Encrypting an entire system:) 3.5 Configuring the boot loader" "https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_the_boot_loader_2"
	runcommand "$(sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$(lsblk -lpno NAME,UUID | awk -v cryptpart=$CRYPT_PART '$1 == cryptpart { print $2 }')\:$CRYPT_MAPPER_NAME root=\/dev\/$LVM_VG_NAME\/root /" /mnt/etc/default/grub)" "sed -i \"s/GRUB_CMDLINE_LINUX_DEFAULT=\\\"/GRUB_CMDLINE_LINUX_DEFAULT=\\\"cryptdevice=UUID=\$(lsblk -lpno NAME,UUID | awk -v cryptpart=$CRYPT_PART '\$1 == cryptpart { print \$2 }')\\:$CRYPT_MAPPER_NAME root=\\/dev\\/$LVM_VG_NAME\\/root /\" /mnt/etc/default/grub"
	runcommand "$(arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null)" "arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null"
}

#MAIN STEPS ####################################################################
prep() {
	#-----------------------------------------------------------------------
	# load data to prepare the installation process
	#-----------------------------------------------------------------------
	setmetavariables
	if [[ "$PRINT_OUTPUT_LOGFILE" == "true" ]] && [[ -f $LOG_FILE ]] && [[ "$LOG_APPEND" == "false" ]]; then
		rm -f $LOG_FILE
	fi
	greeting
	setvariables
	setarrays
}

loadkeymap() {
	#-----------------------------------------------------------------------
	# load the keymap
	#-----------------------------------------------------------------------
	mainsteptitle "1.5 Set the console keyboard layout" "https://wiki.archlinux.org/title/Installation_guide#Set_the_console_keyboard_layout"
	runcommand "loadkeys $KEYMAP"
}

verifybootmode() {
	#-----------------------------------------------------------------------
	# verify the boot mode
	# exit, if boot mode is not UEFI
	#-----------------------------------------------------------------------
	mainsteptitle "1.6 Verify the boot mode" "https://wiki.archlinux.org/title/Installation_guide#Verify_the_boot_mode"
	runcommand "test -d /sys/firmware/efi/efivars"
}

checkinternetconnection() {
	#-----------------------------------------------------------------------
	# check internetconnection
	# exit, if there is no working internet connection
	#-----------------------------------------------------------------------
	mainsteptitle "1.7 Connect to the internet" "https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet"
	runcommand "test $(ping -c1 archlinux.org | awk '/1 packets transmitted/ {print $4}') -eq 1" "test \$(ping -c1 archlinux.org | awk '/1 packets transmitted/ {print \$4}') -eq 1"
}

updatesystemclock() {
	#-----------------------------------------------------------------------
	# update the system clock
	# ensures, the system clock is accurate
	#-----------------------------------------------------------------------
	mainsteptitle "1.8 Update the system clock" "https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock"
	runcommand "timedatectl set-ntp true"
}

partitiondisks() {
	#-----------------------------------------------------------------------
	# partitions the disk
	# prepares logical volumes I
	#-----------------------------------------------------------------------
	mainsteptitle "1.9 Partition the disks" "https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks"
	warning "if you continue, you will lose all data on ${FOREGROUND_MAGENTA}$TARGET_DISK"
	preparingdisk
	preparinglogicalvolumes1
}

formatpartitions() {
	#-----------------------------------------------------------------------
	# formats the partitions and logical volumes
	#-----------------------------------------------------------------------
	mainsteptitle "1.10 Format the partitions" "https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions"
	preparinglogicalvolumes2
	preparingbootpart1
}

mountfilesystems() {
	#-----------------------------------------------------------------------
	# mount the filesystems on the partitions and logical volumes
	#-----------------------------------------------------------------------
	mainsteptitle "1.11 Mount the file systems" "https://wiki.archlinux.org/title/Installation_guide#Mount_the_file_systems"
	preparinglogicalvolumes3
	preparingbootpart2
}

selectmirrors() {
	#-----------------------------------------------------------------------
	# change the mirrorlist using the reflector command
	#-----------------------------------------------------------------------
	mainsteptitle "2.1 Select the mirrors" "https://wiki.archlinux.org/title/Installation_guide#Select_the_mirrors"
	runcommand "$(printf "%s\n" "--country $MIRROR_COUNTRIES" >>/etc/xdg/reflector/reflector.conf)" "printf \"%s\\n\" \"--country $MIRROR_COUNTRIES\" >>/etc/xdg/reflector/reflector.conf"
	runcommand "$(printf "%s\n" "--age 12" >>/etc/xdg/reflector/reflector.conf)" "printf \"%s\\n\" \"--age 12\" >>/etc/xdg/reflector/reflector.conf"
	runcommand "systemctl start reflector.service"
}

installessentialpackages() {
	#-----------------------------------------------------------------------
	# installs the essential packages to the mounted filesystem
	#-----------------------------------------------------------------------
	mainsteptitle "2.2 Install essential packages" "https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages"
	for i in ${essentialpackages[@]}; do
		runcommand "pacstrap /mnt $i"
	done
}

fstab() {
	#-----------------------------------------------------------------------
	# generate an fstab file
	#-----------------------------------------------------------------------
	mainsteptitle "3.1 Fstab" "https://wiki.archlinux.org/title/Installation_guide#Fstab"
	runcommand "$(genfstab -U /mnt >>/mnt/etc/fstab)" "genfstab -U /mnt >> /mnt/etc/fstab"
}

chrootintoarch() {
	#-----------------------------------------------------------------------
	# explains in output, why this step won't be integrated in this script
	#-----------------------------------------------------------------------
	mainsteptitle "3.2 Chroot" "https://wiki.archlinux.org/title/Installation_guide#Chroot"
	printlogstdout "this step is skipped. it is not necessary to perform this step by itself."
	printlogstdout "while it would be easier for a manual installation for the following steps,"
	printlogstdout "for installing arch linux with a bash script, it is easier to put an"
	printlogstdout "\"arch-chroot /mnt \" in front of each of the following steps instead."
}

timezone() {
	#-----------------------------------------------------------------------
	# sets the time zone and generates /etc/adjtime
	#-----------------------------------------------------------------------
	mainsteptitle "3.3 Time zone" "https://wiki.archlinux.org/title/Installation_guide#Time_zone"
	runcommand "arch-chroot /mnt ln -sf /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime"
	runcommand "arch-chroot /mnt hwclock --systohc"
}

localization() {
	#-----------------------------------------------------------------------
	# setup the locales
	#-----------------------------------------------------------------------
	mainsteptitle "3.4 Localization" "https://wiki.archlinux.org/title/Installation_guide#Localization"
	for i in ${locales[@]}; do
		local SUFFIX=$(awk -v locale="#$i" '$1 == locale {print $2}' /mnt/etc/locale.gen)
		runcommand "$(printf "%s\n" "$i $SUFFIX" >>/mnt/etc/locale.gen)" "printf \"%s\\n\" \"$i $SUFFIX\" >> /mnt/etc/locale.gen"
	done
	runcommand "arch-chroot /mnt locale-gen"
	for i in ${localevariables[@]}; do
		local LOCALIZATION=$(value $i "VARIABLE" "LOCALIZATION" "LOCALIZATIONS")
		runcommand "$(printf "%s\n" "$i=$LOCALIZATION" >>/mnt/etc/locale.conf)" "printf \"%s\\n\" \"$i=$LOCALIZATION\" >> /mnt/etc/locale.conf"
	done
	runcommand "$(printf "%s\n" "KEYMAP=$KEYMAP" >>/mnt/etc/vconsole.conf)" "printf \"%s\\n\" \"KEYMAP=$KEYMAP\" >> /mnt/etc/vconsole.conf"
}

networkconfig() {
	#-----------------------------------------------------------------------
	# create the hostname and complete the network configuration
	#-----------------------------------------------------------------------
	mainsteptitle "3.5 Network configuration" "https://wiki.archlinux.org/title/Installation_guide#Network_configuration"
	runcommand "$(printf "%s\n" "$HOST_NAME" >>/mnt/etc/hostname)" "printf \"%s\\n\" \"$HOST_NAME\" >> /mnt/etc/hostname"
	localhostnameresolution
	rundhcpcd
}

initramfs() {
	#-----------------------------------------------------------------------
	# create the initramfs
	#-----------------------------------------------------------------------
	mainsteptitle "3.6 Initramfs" "https://wiki.archlinux.org/title/Installation_guide#Initramfs"
	configuringmkinitcpio
	runcommand "$(arch-chroot /mnt mkinitcpio -P &>/dev/null)" "arch-chroot /mnt mkinitcpio -P &>/dev/null"
}

rootpassword() {
	#-----------------------------------------------------------------------
	# sets the root password
	#-----------------------------------------------------------------------
	mainsteptitle "3.7 Root password" "https://wiki.archlinux.org/title/Installation_guide#Root_password"
	setpassphrase "root user" "PW_ROOT"
	runcommand "$(printf "$PW_ROOT\n$PW_ROOT" | arch-chroot /mnt passwd --quiet &>/dev/null)" "printf \"*****\\n*****\" | arch-chroot /mnt passwd --quiet &>/dev/null"
	unset PW_ROOT
}

bootloader() {
	#-----------------------------------------------------------------------
	# install and setup the boot loader and enable microcode
	#-----------------------------------------------------------------------
	mainsteptitle "3.8 Boot loader" "https://wiki.archlinux.org/title/Installation_guide#Boot_loader"
	grubinstallation
	microcodeinstallation
	grubconfiguration
}

#MAIN ##########################################################################
main() {
	#-----------------------------------------------------------------------
	# installs arch linux step by step
	#-----------------------------------------------------------------------
	prep
	loadkeymap
	verifybootmode
	checkinternetconnection
	updatesystemclock
	partitiondisks
	formatpartitions
	mountfilesystems
	selectmirrors
	installessentialpackages
	fstab
	chrootintoarch
	timezone
	localization
	networkconfig
	initramfs
	rootpassword
	bootloader
}

#START #########################################################################
while getopts ":hvrlL:c:d:" opt; do
	case ${opt} in
	h)
		usage
		abortquietly 0
		;;
	v)
		PRINT_OUTPUT_STDOUT="true"
		clear
		;;
	r)
		LOG_APPEND="false"
		;;
	l)
		PRINT_OUTPUT_LOGFILE="true"
		;;
	L)
		PRINT_OUTPUT_LOGFILE="true"
		LOG_FILE="${OPTARG}"
		;;
	c)
		CONFIGFILE="${OPTARG}"
		;;
	d)
		TARGET_DISK="${OPTARG}"
		;;
	:)
		printf "%b\n" "-${OPTARG} requires an argument"
		usage
		abortquietly 1
		;;
	\?)
		printf "%b\n" "-${OPTARG} is not a valid option"
		usage
		abortquietly 1
		;;
	esac
done
main
exit 0
