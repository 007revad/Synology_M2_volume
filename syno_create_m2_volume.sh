#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
# Create volume on M.2 drive(s) on Synology models that don't have a GUI option
#
# Github: https://github.com/007revad/Synology_M2_volume
# Script verified at https://www.shellcheck.net/
# Tested on DSM 7.2 beta
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo /volume1/scripts/create_m2_volume.sh
#
# Resources:
# https://academy.pointtosource.com/synology/synology-ds920-nvme-m2-ssd-volume/amp/
# https://www.reddit.com/r/synology/comments/pwrch3/how_to_create_a_usable_poolvolume_to_use_as/
#
# Over-Provisioning unnecessary on modern SSDs (since ~2014)
# https://easylinuxtipsproject.blogspot.com/p/ssd.html#ID16.2
#-----------------------------------------------------------------------------------

# TODO
# Better detection if DSM is using the drive.
# Show drive names the same as DSM does.
# Support SATA M.2 drives.
# Maybe add logging.
# Add option to repair damaged array? DSM can probably handle this.

# DONE
# Changed to not show RAID 1 when Single drive selected.
# Changed so the Done choice only appears when enough drives have been selected.
# Changed to say "This can take while" instead of "This can take an hour".
#
# Added support for RAID 6 and RAID 10 (thanks Raj)
# Added support for an unlimited number of M.2 drives for RAID 0, 5, 6 and 10.
#  https://kb.synology.com/en-in/DSM/tutorial/What_is_RAID_Group
# Now shows how long the resync took.
# The script now automatically reloads after updating itself.
#
# Added DSM 6 support (WIP)
#
# Added support for RAID 5
# Changed to not include the 1st selected drive in the choices for 2nd drive etc.
#
# Fixed "download new version" failing if script was run via symlink or ./<scriptname>
#
# Check for errors from synopartition, mdadm, pvcreate and vgcreate 
#   so the script doesn't continue and appear to have succeeded.
#
# Changed "pvcreate" to "pvcreate -ff" to avoid issues.
#
# Changed latest version check to download to /tmp and extract files to the script's location,
# replacing the existing .sh and readme.txt files.
#
# Added single progress bar for the resync progress.
#
# Added options:
#  -a, --all        List all M.2 drives even if detected as active
#  -s, --steps      Show the steps to do after running this script
#  -h, --help       Show this help message
#  -v, --version    Show the script version
#
# Added -s, --steps option to show required steps after running script.
#
# Show DSM version and NAS model (to make it easier to debug)
# Changed for DSM 7.2 and older DSM version:
# - For DSM 7.x
#   - Ensures m2 volume support is enabled.
#   - Creates RAID and storage pool only.
# - For DSM 6.2.4 and earlier
#   - Creates RAID, storage pool and volume.
#
#
# Allow specifying the size of the volume to leave unused space for drive wear management.
#
# Instead of creating the filesystem directly on the mdraid device, you can use LVM to create a PV on it,
# and a VG, and then use the UI to create volume(s), making it more "standard" to what DSM would do.
# https://systemadmintutorial.com/how-to-configure-lvm-in-linuxpvvglv/
#
# Physical Volume (PV): Consists of Raw disks or RAID arrays or other storage devices.
# Volume Group (VG): Combines the physical volumes into storage groups.
# Logical Volume (LV): VG's are divided into LV's and are mounted as partitions.


scriptver="v1.3.22"
script=Synology_M2_volume
repo="007revad/Synology_M2_volume"
scriptname=syno_create_m2_volume

# Check BASH variable is bash
if [ ! "$(basename "$BASH")" = bash ]; then
    echo "This is a bash script. Do not run it with $(basename "$BASH")"
    printf \\a
    exit 1
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo "This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology"
    echo "and run it from there."
    exit 1
fi

# Shell Colors
#Black='\e[0;30m'   # ${Black}
Red='\e[0;31m'      # ${Red}
#Green='\e[0;32m'   # ${Green}
Yellow='\e[0;33m'  # ${Yellow}
#Blue='\e[0;34m'    # ${Blue}
#Purple='\e[0;35m'  # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'   # ${White}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

ding(){ 
    printf \\a
}

usage(){ 
    cat <<EOF
$script $scriptver - by 007revad

Usage: $(basename "$0") [options]

Options:
  -a, --all        List all M.2 drives even if detected as active
  -s, --steps      Show the steps to do after running this script
  -h, --help       Show this help message
  -v, --version    Show the script version

EOF
    exit 0
}


scriptversion(){ 
    cat <<EOF
$script $scriptver - by 007revad

See https://github.com/$repo
EOF
    exit 0
}


createpartition(){ 
    if [[ $1 ]]; then
        echo -e "\nCreating Synology partitions on $1" >&2
        if [[ $dryrun == "yes" ]]; then
            echo "synopartition --part /dev/$1 $synopartindex" >&2  # dryrun
        else
            if ! synopartition --part /dev/"$1" "$synopartindex"; then
                echo -e "\n${Error}ERROR 5${Off} Failed to create syno partitions!" >&2
                exit 1
            fi
        fi
    fi
}


selectdisk(){ 
    if [[ ${#m2list[@]} -gt "0" ]]; then

        # Only show Done choice when required number of drives selected
        if [[ $single != "yes" ]] && [[ "${#mdisk[@]}" -ge "$mindisk" ]]; then
            showDone=" Done"
        else
            showDone=""
        fi

        select nvmes in "${m2list[@]}"$showDone; do
            case "$nvmes" in
                Done)
                    Done="yes"
                    selected_disk=""
                    break
                    ;;
                Quit)
                    exit
                    ;;
                nvme*)
#                    if [[ " ${m2list[*]} "  =~ " ${nvmes} " ]]; then
                        selected_disk="$nvmes"
                        break
#                    else
#                        echo -e "${Red}Invalid answer!${Off} Try again." >&2
#                        selected_disk=""
#                    fi
                    ;;
                *)
                    echo -e "${Red}Invalid answer!${Off} Try again." >&2
                    selected_disk=""
                    ;;
            esac
        done

        if [[ $Done != "yes" ]] && [[ $selected_disk ]]; then
            mdisk+=("$selected_disk")
            # Remove selected drive from list of selectable drives
            remelement "$selected_disk"
            # Keep track of many drives user selected
            selected="$((selected +1))"
            echo -e "You selected ${Cyan}$selected_disk${Off}" >&2

            #echo "Drives selected: $selected" >&2  # debug
        fi
        echo
    else
        Done="yes"
    fi
}


showsteps(){ 
    echo -e "\n${Cyan}Steps you need to do after running this script:${Off}" >&2
    major=$(get_key_value /etc.defaults/VERSION major)
    if [[ $major -gt "6" ]]; then
        cat <<EOF
  1. After the restart go to Storage Manager and select online assemble:
       Storage Pool > Available Pool > Online Assemble
  2. Create the volume as you normally would:
       Select the new Storage Pool > Create > Create Volume
  3. Optionally enable TRIM:
       Storage Pool > ... > Settings > SSD TRIM
EOF
    echo -e "     ${Cyan}SSD TRIM option is only available in DSM 7.2 Beta for RAID 1${Off}" >&2
    echo -e "\n${Error}Important${Off}" >&2
    cat <<EOF
If you later upgrade DSM and your M.2 drives are shown as unsupported
and the storage pool is shown as missing, and online assemble fails,
you should run the Synology HDD db script:
EOF
    echo -e "${Cyan}https://github.com/007revad/Synology_HDD_db${Off}\n" >&2
    fi
    #return
}


# Save options used
args=("$@")


# Check for flags with getopt
# shellcheck disable=SC2034
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -a \
    -l all,steps,help,version,log,debug -- "$@")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            -a|--all)           # List all M.2 drives even if detected as active
                all=yes
                ;;
            -s|--steps)         # Show steps remaining after running script
                showsteps
                exit
                ;;
            -h|--help)          # Show usage options
                usage
                ;;
            -v|--version)       # Show script version
                scriptversion
                ;;
            -l|--log)            # Log
                log=yes
                ;;
            -d|--debug)          # Show and log debug info
                debug=yes
                ;;
            -r)                  # Simulate 4 NVMe drives for dry run testing
                raid5=yes
                dryrun=yes
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                echo -e "Invalid option '$1'\n"
                usage "$1"
                ;;
        esac
        shift
    done
else
    echo
    usage
fi


if [[ $debug == "yes" ]]; then
    set -x
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`:.$LINENO:'
fi


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM major and minor versions
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
dsminor=$(get_key_value /etc.defaults/VERSION minorversion)
# shellcheck disable=SC2034
if [[ $dsm -gt "6" ]] && [[ $dsminor -gt "1" ]]; then
    dsm72="yes"
fi
if [[ $dsm -gt "6" ]] && [[ $dsminor -gt "0" ]]; then
    dsm71="yes"
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
hwrevision=$(cat /proc/sys/kernel/syno_hw_revision)
if [[ $hwrevision =~ r[0-9] ]]; then showhwrev=" $hwrevision"; fi

# Get DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
smallfixnumber=$(get_key_value /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "${model}$showhwrev DSM $productversion-$buildnumber$smallfix $buildphase\n"


# Get StorageManager version
storagemgrver=$(synopkg version StorageManager)
# Show StorageManager version
if [[ $storagemgrver ]]; then echo -e "StorageManager $storagemgrver\n"; fi


# Show options used
echo -e "Using options: ${args[*]}\n"


#------------------------------------------------------------------------------
# Check latest release with GitHub API

# Get latest release info
# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
release=$(curl --silent -m 10 --connect-timeout 5 \
    "https://api.github.com/repos/$repo/releases/latest")

# Release version
tag=$(echo "$release" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
shorttag="${tag:1}"

# Get script location
# https://stackoverflow.com/questions/59895/
source=${BASH_SOURCE[0]}
while [ -L "$source" ]; do # Resolve $source until the file is no longer a symlink
    scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    # If $source was a relative symlink, we need to resolve it
    # relative to the path where the symlink file was located
    [[ $source != /* ]] && source=$scriptpath/$source
done
scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
scriptfile=$( basename -- "$source" )
echo "Running from: ${scriptpath}/$scriptfile"

#echo "Script location: $scriptpath"  # debug
#echo "Source: $source"               # debug
#echo "Script filename: $scriptfile"  # debug

#echo "tag: $tag"              # debug
#echo "scriptver: $scriptver"  # debug


# Warn if script located on M.2 drive
scriptvol=$(echo "$scriptpath" | cut -d"/" -f2)
vg=$(lvdisplay | grep /volume_"${scriptvol#volume}" | cut -d"/" -f3)
md=$(pvdisplay | grep -B 1 -E '[ ]'"$vg" | grep /dev/ | cut -d"/" -f3)
if cat /proc/mdstat | grep "$md" | grep nvme >/dev/null; then
    echo -e "${Yellow}WARNING${Off} Don't store this script on an NVMe volume!"
fi


cleanup_tmp(){ 
    # Delete downloaded .tar.gz file
    if [[ -f "/tmp/$script-$shorttag.tar.gz" ]]; then
        if ! rm "/tmp/$script-$shorttag.tar.gz"; then
            echo -e "${Error}ERROR${Off} Failed to delete"\
                "downloaded /tmp/$script-$shorttag.tar.gz!" >&2
        fi
    fi

    # Delete extracted tmp files
    if [[ -d "/tmp/$script-$shorttag" ]]; then
        if ! rm -r "/tmp/$script-$shorttag"; then
            echo -e "${Error}ERROR${Off} Failed to delete"\
                "downloaded /tmp/$script-$shorttag!" >&2
        fi
    fi
}


if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    scriptdl="$scriptpath/$script-$shorttag"
    if [[ -f ${scriptdl}.tar.gz ]] || [[ -f ${scriptdl}.zip ]]; then
        # They have the latest version tar.gz downloaded but are using older version
        echo "You have the latest version downloaded but are using an older version"
        sleep 10
    elif [[ -d $scriptdl ]]; then
        # They have the latest version extracted but are using older version
        echo "You have the latest version extracted but are using an older version"
        sleep 10
    else
        echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
        read -r -t 30 reply
        if [[ ${reply,,} == "y" ]]; then
            # Delete previously downloaded .tar.gz file and extracted tmp files
            cleanup_tmp

            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -JLO -m 30 --connect-timeout 5 "$url"; then
                    echo -e "${Error}ERROR${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to /tmp/<script-name>
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; then
                            echo -e "${Error}ERROR${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                        else
                            # Set script sh files as executable
                            if ! chmod a+x "/tmp/$script-$shorttag/"*.sh ; then
                                permerr=1
                                echo -e "${Error}ERROR${Off} Failed to set executable permissions"
                            fi

                            # Copy new script sh file to script location
                            if ! cp -p "/tmp/$script-$shorttag/${scriptname}.sh" "${scriptpath}/${scriptfile}";
                            then
                                copyerr=1
                                echo -e "${Error}ERROR${Off} Failed to copy"\
                                    "$script-$shorttag sh file(s) to:\n $scriptpath/${scriptfile}"
                            fi

                            # Copy new CHANGES.txt file to script location (if script on a volume)
                            if [[ $scriptpath =~ /volume* ]]; then
                                # Set permsissions on CHANGES.txt
                                if ! chmod 664 "/tmp/$script-$shorttag/CHANGES.txt"; then
                                    permerr=1
                                    echo -e "${Error}ERROR${Off} Failed to set permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi

                                # Copy new CHANGES.txt file to script location
                                if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt"\
                                    "${scriptpath}/${scriptname}_CHANGES.txt";
                                then
                                    copyerr=1
                                    echo -e "${Error}ERROR${Off} Failed to copy"\
                                        "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                                else
                                    changestxt=" and changes.txt"
                                fi
                            fi

                            # Delete downloaded tmp files
                            cleanup_tmp

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag ${scriptfile}$changestxt downloaded to: ${scriptpath}\n"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "${scriptpath}/$scriptfile" "${args[@]}"
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                    fi
                fi
                cd "$scriptpath" || echo -e "${Error}ERROR${Off} Failed to cd to script location!"
            else
                echo -e "${Error}ERROR${Off} Failed to cd to /tmp!"
            fi
        fi
    fi
fi


echo -e "Type ${Cyan}yes${Off} to continue."\
    "Type anything else to do a ${Cyan}dry run test${Off}."
read -r answer
if [[ ${answer,,} != "yes" ]]; then dryrun="yes"; fi
if [[ $dryrun == "yes" ]]; then
    echo -e "*** Doing a dry run test ***\n"
    sleep 1  # Make sure they see they're running a dry run test
else
    echo
fi


#--------------------------------------------------------------------
# Check there's no active resync

if grep resync /proc/mdstat >/dev/null ; then
    ding
    echo "The Synology is currently doing a RAID resync or data scrub!"
    exit
fi


#--------------------------------------------------------------------
# Get list of M.2 drives

getm2info(){ 
    nvmemodel=$(cat "$1/device/model")
    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading/trailing space
    echo "$2 M.2 $(basename -- "${1}") is $nvmemodel" >&2
    dev="$(basename -- "${1}")"

    #echo "/dev/${dev}" >&2  # debug

    if [[ $all != "yes" ]]; then
        # Skip listing M.2 drives detected as active
        if grep -E "active.*${dev}" /proc/mdstat >/dev/null ; then
            echo -e "${Cyan}Skipping drive as it is being used by DSM${Off}" >&2
            echo "" >&2
            #active="yes"
            return
        fi
    fi

    if [[ -e /dev/${dev}p1 ]] && [[ -e /dev/${dev}p2 ]] &&\
            [[ -e /dev/${dev}p3 ]]; then
        echo -e "${Cyan}WARNING Drive has a volume partition${Off}" >&2
        haspartitons="yes"
    elif [[ ! -e /dev/${dev}p3 ]] && [[ ! -e /dev/${dev}p2 ]] &&\
            [[ -e /dev/${dev}p1 ]]; then
        echo -e "${Cyan}WARNING Drive has a cache partition${Off}" >&2
        haspartitons="yes"
    elif [[ ! -e /dev/${dev}p3 ]] && [[ ! -e /dev/${dev}p2 ]] &&\
            [[ ! -e /dev/${dev}p1 ]]; then
        echo "No existing partitions on drive" >&2
    fi
    m2list+=("${dev}")
    echo "" >&2
}

for d in /sys/block/*; do
    case "$(basename -- "${d}")" in
        nvme*)  # M.2 NVMe drives
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                getm2info "$d" "NVMe"
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe card only?)
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                getm2info "$d" "SATA"
            fi
        ;;
        *)
          ;;
    esac
done

#echo -e "Inactive M.2 drives found: ${#m2list[@]}\n"
echo -e "Unused M.2 drives found: ${#m2list[@]}\n"

#echo -e "NVMe list: ${m2list[@]}\n"  # debug
#echo -e "NVMe qty: ${#m2list[@]}\n"  # debug

if [[ ${#m2list[@]} == "0" ]]; then exit; fi


#--------------------------------------------------------------------
# Select RAID type (if multiple M.2 drives found)

if [[ ${#m2list[@]} -gt "1" ]]; then
    PS3="Select the RAID type: "
    if [[ ${#m2list[@]} -eq "2" ]]; then
        options=("Single" "RAID 0" "RAID 1")
    elif [[ ${#m2list[@]} -gt "2" ]]; then
        options=("Single" "RAID 0" "RAID 1" "RAID 5" "RAID 6" "RAID 10")
    fi
    select raid in "${options[@]}"; do
      case "$raid" in
        "Single")
            raidtype="1"
            single="yes"
            mindisk=1
            #maxdisk=1
            break
            ;;
        "RAID 0")
            raidtype="0"
            mindisk=2
            #maxdisk=24
            break
            ;;
        "RAID 1")
            raidtype="1"
            mindisk=2
            #maxdisk=4
            break
            ;;
        "RAID 5")
            raidtype="5"
            mindisk=3
            #maxdisk=24
            break
            ;;
        "RAID 6")
            raidtype="6"
            mindisk=4
            #maxdisk=24
            break
            ;;
        "RAID 10")
            raidtype="10"
            mindisk=4
            #maxdisk=24
            break
            ;;
        Quit)
            exit
            ;;
        *)
            echo -e "${Red}Invalid answer!${Off} Try again."
            ;;
      esac
    done
    if [[ $single == "yes" ]]; then
        echo -e "You selected ${Cyan}Single${Off}"
    else
        echo -e "You selected ${Cyan}RAID $raidtype${Off}"
    fi
    echo
elif [[ ${#m2list[@]} -eq "1" ]]; then
    raidtype="1"
    single="yes"
fi

if [[ $single == "yes" ]]; then
    maxdisk=1
elif [[ $raidtype == "1" ]]; then
    maxdisk=4
#else
    # Only Basic and RAID 1 have a limit on the number of drives in DSM 7 and 6
    # Later we set maxdisk to the number of M.2 drives found if not Single or RAID 1
#    maxdisk=24
fi


#--------------------------------------------------------------------
# Selected M.2 drive functions

getindex(){ 
    # Get array index from value
    for i in "${!m2list[@]}"; do
        if [[ "${m2list[$i]}" == "${1}" ]]; then
            r="${i}"
        fi
    done
    return "$r"
}


remelement(){ 
    # Remove selected drive from list of other selectable drives
    if [[ $1 ]]; then
        num="0"
        while [[ $num -lt "${#m2list[@]}" ]]; do
            if [[ ${m2list[num]} == "$1" ]]; then
                # Remove selected drive from m2list array
                unset "m2list[num]"

                # Rebuild the array to remove empty indices
                for i in "${!m2list[@]}"; do
                    tmp_array+=( "${m2list[i]}" )
                done
                m2list=("${tmp_array[@]}")
                unset tmp_array
            fi
            num=$((num +1))
        done
    fi
}


#--------------------------------------------------------------------
# Select M.2 drives

mdisk=(  )

# Set maxdisk to the number of M.2 drives found if not Single or RAID 1
# Only Basic and RAID 1 have a limit on the number of drives in DSM 7 and 6
if [[ $single != "yes" ]] && [[ $raidtype != "1" ]]; then
    maxdisk="${#m2list[@]}"
fi

while [[ $selected -lt "$mindisk" ]] || [[ $selected -lt "$maxdisk" ]]; do
    if [[ $single == "yes" ]]; then
        PS3="Select the M.2 drive: "
    else
        PS3="Select the M.2 drive #$((selected+1)): "
    fi
    selectdisk
    if [[ $Done == "yes" ]]; then
        break
    fi
done

if [[ $selected -lt "$mindisk" ]]; then
    echo "Drives selected: $selected"
    echo -e "${Error}ERROR${Off} You need to select $mindisk or more drives for RAID $raidtype"
    exit
fi


#--------------------------------------------------------------------
# Select file system - only DSM 6.2.4 and lower

if [[ $dsm == "6" ]]; then
    PS3="Select the file system: "
    select filesys in "btrfs" "ext4"; do
        case "$filesys" in
            btrfs)
                echo -e "You selected ${Cyan}btrfs${Off}"  # debug
                format="btrfs"
                break
                ;;
            ext4)
                echo -e "You selected ${Cyan}ext4${Off}"  # debug
                format="ext4"
                break
                ;;
            *)
                echo -e "${Red}Invalid answer${Off}! Try again."
                ;;
        esac
    done
    #echo
fi


#--------------------------------------------------------------------
# Let user confirm their choices

if [[ $format == "btrfs" ]] || [[ $format == "ext4" ]]; then
    formatshow="$format "
fi

if [[ $single == "yes" ]]; then
    echo -en "Ready to create volume group using ${Cyan}${mdisk[*]}${Off}"
else
    echo -en "Ready to create ${Cyan}${formatshow}RAID $raidtype${Off} volume group using "
    echo -e "${Cyan}${mdisk[*]}${Off}"
fi

if [[ $haspartitons == "yes" ]]; then
    echo -e "\n${Red}WARNING${Off} Everything on the selected"\
        "M.2 drive(s) will be deleted."
fi
if [[ $dryrun == "yes" ]]; then
    echo -e "        *** Not really because we're doing"\
        "a ${Cyan}dry run${Off} ***"
fi

echo -e "Type ${Cyan}yes${Off} to continue. Type anything else to quit."
read -r answer
if [[ ${answer,,} != "yes" ]]; then exit; fi


# Abandon hope, all ye who enter here :)
echo -e "You chose to continue. You are brave! :)\n"
sleep 1


#--------------------------------------------------------------------
# Get highest md# mdraid device

# Using "md[0-9]{1,2}" to avoid md126 and md127 etc
lastmd=$(grep -oP "md[0-9]{1,2}" "/proc/mdstat" | sort | tail -1)
nextmd=$((${lastmd:2} +1))
if [[ -z $nextmd ]]; then
    ding
    echo -e "${Error}ERROR${Off} Next md number not found!"
    exit 1
else
    echo "Using md$nextmd as it's the next available."
fi


#--------------------------------------------------------------------
# Create Synology partitions on selected M.2 drives

if [[ $dsm == "7" ]]; then
    synopartindex=13  # Syno partition index for NVMe drives can be 12 or 13 or ?
else
    synopartindex=12  # Syno partition index for NVMe drives can be 12 or 13 or ?
fi

partargs=(  )
for i in "${mdisk[@]}"
do
   :
   createpartition "$i"
   partargs+=(
       /dev/"${i}"p3
   )
done


#--------------------------------------------------------------------
# Create the RAID array
# --level=0 for RAID 0  --level=1 for RAID 1  --level=5 for RAID 5

#if [[ $raidtype ]]; then

SECONDS=0  # To work out how long the resync took

echo -e "\nCreating the RAID array. This will take a while..."
if [[ $dryrun == "yes" ]]; then
    echo "mdadm --create /dev/md${nextmd} --level=${raidtype} --raid-devices=$selected"\
        --force "${partargs[@]}"                # dryrun
else
    if ! mdadm --create /dev/md"${nextmd}" --level="${raidtype}" --raid-devices="$selected"\
        --force "${partargs[@]}"; then
            ding
        echo -e "\n${Error}ERROR 5${Off} Failed to create RAID!"
        exit 1
    fi
fi

# Show resync progress every 5 seconds
if [[ $dryrun == "yes" ]]; then
    echo -ne "      [====>................]  resync = 20%\r"; sleep 1  # dryrun
    echo -ne "      [========>............]  resync = 40%\r"; sleep 1  # dryrun
    echo -ne "      [============>........]  resync = 60%\r"; sleep 1  # dryrun
    echo -ne "      [================>....]  resync = 80%\r"; sleep 1  # dryrun
    echo -ne "      [====================>]  resync = 100%\r\n"        # dryrun
else
    while grep resync /proc/mdstat >/dev/null; do
        # Only multi-drive RAID gets re-synced
        progress="$(grep -E -A 2 active.*nvme /proc/mdstat | grep resync | cut -d\( -f1 )"
        echo -ne "$progress\r"
        sleep 5
    done
    # Show 100% progress
    if [[ $progress ]]; then
        echo -ne "      [====================>]  resync = 100%\r"
    fi
fi

# Show how long the resync took
end=$SECONDS
if [[ $end -ge 3600 ]]; then
    printf '\nResync Duration: %d hr %d min\n' $((end/3600)) $((end%3600/60))
elif [[ $end -ge 60 ]]; then
    echo -e "\nResync Duration: $(( end / 60 )) min"
else
    echo -e "\nResync Duration: $end sec"
fi


#--------------------------------------------------------------------
# Create Physical Volume and Volume Group with LVM - DSM 7 only

# Create a physical volume (PV) on the partition
if [[ $dsm -gt "6" ]]; then
    echo -e "\nCreating a physical volume (PV) on md$nextmd partition"
    if [[ $dryrun == "yes" ]]; then
        echo "pvcreate -ff /dev/md$nextmd"                              # dryrun
    else
        if ! pvcreate -ff /dev/md$nextmd ; then
            ding
            echo -e "\n${Error}ERROR 5${Off} Failed to create physical volume!"
            exit 1
        fi
    fi
fi

# Create a volume group (VG)
if [[ $dsm -gt "6" ]]; then
    echo -e "\nCreating a volume group (VG) on md$nextmd partition"
    if [[ $dryrun == "yes" ]]; then
        echo "vgcreate vg$nextmd /dev/md$nextmd"                        # dryrun
    else
        if ! vgcreate vg$nextmd /dev/md$nextmd ; then
            ding
            echo -e "\n${Error}ERROR 5${Off} Failed to create volume group!"
            exit 1
        fi
    fi
fi


#--------------------------------------------------------------------
# Format array - only DSM 6.2.4 and lower

if [[ $dsm == "6" ]]; then
    if [[ $format == "btrfs" ]]; then
        if [[ $dryrun == "yes" ]]; then
            echo "echo 0 > /sys/block/md${nextmd}/queue/rotational"  # dryrun
            echo "mkfs.btrfs -f /dev/md${nextmd}"                    # dryrun
        else
            # Ensure mkfs.btrfs sees raid as SSD and optimises file system for SSD
            echo 0 > /sys/block/md${nextmd}/queue/rotational
            # Format nvme#np2
            mkfs.btrfs -f /dev/md${nextmd}
        fi
    elif [[ $format == "ext4" ]]; then
        if [[ $dryrun == "yes" ]]; then
            echo "echo 0 > /sys/block/md${nextmd}/queue/rotational"  # dryrun
            echo "mkfs.ext4 -f /dev/md${nextmd}"                     # dryrun
        else
            # Ensure mkfs.ext4 sees raid as SSD and optimises file system for SSD
            echo 0 > /sys/block/md${nextmd}/queue/rotational  # Is this valid for mkfs.ext4 ?
            # Format nvme#np2
            mkfs.ext4 -F /dev/md${nextmd}
        fi
    else
        ding
        echo "What file system did you select!?"; exit
    fi
fi


#--------------------------------------------------------------------
# Enable m2 volume support - DSM 7.1 and later only

# Backup synoinfo.conf if needed
#if [[ $dsm72 == "yes" ]]; then
if [[ $dsm71 == "yes" ]]; then
    synoinfo="/etc.defaults/synoinfo.conf"
    if [[ ! -f ${synoinfo}.bak ]]; then
        if cp "$synoinfo" "$synoinfo.bak"; then
            echo -e "\nBacked up $(basename -- "$synoinfo")" >&2
        else
            ding
            echo -e "\n${Error}ERROR 5${Off} Failed to backup $(basename -- "$synoinfo")!"
            exit 1
        fi
    fi
fi

# Check if m2 volume support is enabled
#if [[ $dsm72 == "yes" ]]; then
if [[ $dsm71 == "yes" ]]; then
    smp=support_m2_pool
    setting="$(get_key_value "$synoinfo" "$smp")"
    enabled=""
    if [[ ! $setting ]]; then
        # Add support_m2_pool="yes"
        echo 'support_m2_pool="yes"' >> "$synoinfo"
        enabled="yes"
    elif [[ $setting == "no" ]]; then
        # Change support_m2_pool="no" to "yes"
        #sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "$synoinfo"
        synosetkeyvalue "$synoinfo" "$smp" "yes"
        enabled="yes"
    elif [[ $setting == "yes" ]]; then
        echo -e "\nM.2 volume support already enabled."
    fi

    # Check if we enabled m2 volume support
    setting="$(get_key_value "$synoinfo" "$smp")"
    if [[ $enabled == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            echo -e "\nEnabled M.2 volume support."
        else
            echo -e "\n${Error}ERROR${Off} Failed to enable m2 volume support!"
        fi
    fi
fi


#--------------------------------------------------------------------
# Notify of remaining steps

echo
showsteps  # Show the final steps to do in DSM


#--------------------------------------------------------------------
# Reboot

echo -e "\n${Cyan}Online assemble option may not appear in storage manager"\
    "until you reboot.${Off}"
echo -e "Type ${Cyan}yes${Off} to reboot now."
echo -e "Type anything else to quit (if you will reboot it yourself)."
read -r answer
if [[ ${answer,,} != "yes" ]]; then exit; fi
if [[ $dryrun == "yes" ]]; then
    echo "reboot"  # dryrun
else
#    # Reboot in the background so user can see DSM's "going down" message
#    reboot &
    if [[ -x /usr/syno/sbin/synopoweroff ]]; then
        /usr/syno/sbin/synopoweroff -r || reboot
    else
        reboot
    fi
fi


#exit  # Don't exit so user can see DSM's "going down" message

