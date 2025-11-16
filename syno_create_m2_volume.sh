#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
# Create volume on M.2 drive(s) on Synology models that don't have a GUI option
#
# Github: https://github.com/007revad/Synology_M2_volume
# Script verified at https://www.shellcheck.net/
# Tested on DSM 7.2 and 7.2.1
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
#
# Use synostgpool instead of synopartition, mdadm and lvm
# https://www.reddit.com/r/synology/comments/17vn96n/how_to_trigger_the_online_assemble_prompt_without/
#-----------------------------------------------------------------------------------

# TODO
# Better detection if DSM is using the drive.
# Maybe add logging.
# Add option to repair damaged array? DSM can probably handle this.

# DONE
# v2 and later are for DSM 7 only.
#   For DSM 6 use v1 without the auto update option.
# Now shows "M.2 Drive #" the same as storage manager.
# Now uses synostgpool command which allows the following: (Thanks to Severe_Pea_2128 on reddit)
#   Now supports JBOD, SHR, SHR2 and RAID F1.
#   Added choice of multi-volume or single-volume storage pool. Multi-volume allows overprovisioning.
#   Added option to skip drive check.
#   No longer need to reboot after running the script.
#   No longer need to do an online assemble.
# Enables RAID F1 if not enabled and RAID F1 selected.
# Removed drive check progress as it was not possible with synostgpool.
# Removed dry run mode as it was not possible with synostgpool.
# Removed support for SATA M.2 drives.

# m2list_assoc contains associative array of [M.2 Drive #]=nvme#n#
# m2list array contains list of "M.2 Drive #"
# mdisk array contains list of selected nvme#n#


scriptver="v2.1.31"
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


declare -A m2list_assoc=( )

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
                "M.2 Drive "*)
                    selected_disk="$nvmes"
                    break
                    ;;
                *)
                    echo -e "${Red}Invalid answer!${Off} Try again." >&2
                    #echo -e "There is no menu item $?)" >&2
                    selected_disk=""
                    ;;
            esac
        done

        if [[ $Done != "yes" ]] && [[ $selected_disk ]]; then
            #mdisk+=("$selected_disk")
            mdisk+=("${m2list_assoc["$selected_disk"]}")
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
    major=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION major)
    if [[ $major -gt "6" ]]; then
        if [[ $pooltype == "single" ]]; then
            echo -e "\n${Cyan}When storage manager has finished checking the drive(s):${Off}"
        else
            echo -e "\n${Cyan}When storage manager has finished creating the storage pool:${Off}"
        fi
        cat <<EOF
  1. Create the volume as you normally would:
       Select the new Storage Pool > Create > Create Volume
  2. Optionally enable TRIM:
       Storage Pool > ... > Settings > SSD TRIM
EOF
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
dsm=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION majorversion)
dsminor=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION minorversion)
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
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "${model}$showhwrev DSM $productversion-$buildnumber$smallfix $buildphase\n"


# Get StorageManager version
storagemgrver=$(/usr/syno/bin/synopkg version StorageManager)
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
echo -e "Running from: ${scriptpath}/$scriptfile\n"

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
                                # Set permissions on CHANGES.txt
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
    local nvme
    local vendor
    local pcislot
    local cardslot
    nvmemodel=$(cat "$1/device/model")
    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading/trailing space

    vendor=$(/usr/syno/bin/synonvme --vendor-get "/dev/$(basename -- "${1}")")
    vendor=" $(printf "%s" "$vendor" | cut -d":" -f2 | xargs)"
    if nvme=$(/usr/syno/bin/synonvme --get-location "/dev/$(basename -- "${1}")"); then
        if [[ ! $nvme =~ "PCI Slot: 0" ]]; then
            pcislot="$(echo "$nvme" | cut -d"," -f2 | awk '{print $NF}')-"
        fi
        cardslot="$(echo "$nvme" | awk '{print $NF}')"
    else
        nvme_cmd_failed="yes"
        pcislot="$(basename -- "${1}")"
        cardslot=""
    fi

    #echo "$2 M.2 $(basename -- "${1}") is $nvmemodel" >&2
    echo "$(basename -- "${1}") M.2 Drive $pcislot$cardslot -$vendor $nvmemodel" >&2
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
        echo -e "${Yellow}WARNING ${Cyan}Drive has a volume partition${Off}" >&2
        haspartitons="yes"
    elif [[ ! -e /dev/${dev}p3 ]] && [[ ! -e /dev/${dev}p2 ]] &&\
            [[ -e /dev/${dev}p1 ]]; then
        echo -e "${Yellow}WARNING ${Cyan}Drive has a cache partition${Off}" >&2
        haspartitons="yes"
    elif [[ ! -e /dev/${dev}p3 ]] && [[ ! -e /dev/${dev}p2 ]] &&\
            [[ ! -e /dev/${dev}p1 ]]; then
        echo "No existing partitions on drive" >&2
    fi
    if [[ $nvme_cmd_failed == "yes" ]]; then
        m2list+=("${dev}")
        m2list_assoc["$dev"]="$dev"
    else
        m2list+=("M.2 Drive $pcislot$cardslot")
        m2list_assoc["M.2 Drive $pcislot$cardslot"]="$dev"
    fi
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
                #getm2info "$d" "SATA"
                echo -e "${Cyan}Skipping SATA M.2 drive${Off}" >&2
                echo -e "Use Synology_M2_volume v1 instead.\n" >&2
            fi
        ;;
        *)
          ;;
    esac
done

echo -e "Unused M.2 drives found: ${#m2list[@]}\n"

#echo -e "NVMe list: ${m2list[@]}\n"  # debug
#echo -e "NVMe qty: ${#m2list[@]}\n"  # debug

if [[ ${#m2list[@]} == "0" ]]; then exit; fi


#--------------------------------------------------------------------
# Select RAID type (if multiple M.2 drives found)

if [[ ${#m2list[@]} -gt "0" ]]; then
    PS3="Select the RAID type: "
    if [[ ${#m2list[@]} -eq "1" ]]; then
        options=("SHR 1" "Basic" "JBOD")
    elif [[ ${#m2list[@]} -eq "2" ]]; then
        options=("SHR 1" "Basic" "JBOD" "RAID 0" "RAID 1")
    elif [[ ${#m2list[@]} -eq "3" ]]; then
        options=("SHR 1" "Basic" "JBOD" "RAID 0" "RAID 1" "RAID 5" "RAID F1")
    elif [[ ${#m2list[@]} -gt "3" ]]; then
        options=("SHR 1" "SHR 2" "Basic" "JBOD" "RAID 0" "RAID 1" "RAID 5" "RAID 6" "RAID 10" "RAID F1")
    fi
    select raid in "${options[@]}"; do
      case "$raid" in
        Basic|Single)
            raidtype="basic"
            single="yes"
            mindisk=1
            #maxdisk=1
            break
            ;;
        JBOD)
            raidtype="linear"
            mindisk=1
            #maxdisk=1
            break
            ;;
        "SHR 1")
            raidtype="SHR1"
            mindisk=1
            #maxdisk=1
            break
            ;;
        "SHR 2")
            raidtype="SHR2"
            mindisk=4
            #maxdisk=1
            break
            ;;
        "RAID 0")
            raidtype="raid0"
            mindisk=2
            #maxdisk=24
            break
            ;;
        "RAID 1")
            raidtype="raid1"
            mindisk=2
            #maxdisk=4
            break
            ;;
        "RAID 5")
            raidtype="raid5"
            mindisk=3
            #maxdisk=24
            break
            ;;
        "RAID 6")
            raidtype="raid6"
            mindisk=4
            #maxdisk=24
            break
            ;;
        "RAID 10")
            raidtype="raid10"
            mindisk=4
            #maxdisk=24
            break
            ;;
        "RAID F1")
            raidtype="raid_f1"
            mindisk=3
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
    echo -e "You selected ${Cyan}$raidtype${Off}\n"
elif [[ ${#m2list[@]} -eq "1" ]]; then
    single="yes"
fi

# Only Basic and RAID 1 have a limit on the number of drives in DSM 7 and 6
# Later we set maxdisk to the number of M.2 drives found if not Single or RAID 1
if [[ $single == "yes" ]]; then
    maxdisk=1
elif [[ $raidtype == "raid1" ]]; then
    maxdisk=4
fi


# Ask user if they want to create a multi-volume pool
echo -e "You have a choice of Multi Volume or Single Volume Storage Pool"
echo -e " - Multi Volume Storage Pools allow creating multiple volumes and"
echo -e "   allow you to over provision to make the NVMe drive(s) last longer."
echo -e " - Single Volume Storage Pools are easier to recover data from"
echo -e "   and perform slightly faster.\n"
PS3="Select the storage pool type: "
#options=("Multi Volume (default)" "Single Volume (easier recovery)")
options=("Multi Volume (DSM 7 default)" "Single Volume")
select pool in "${options[@]}"; do
  case "$pool" in
    #"Multi Volume (default)")
    "Multi Volume (DSM 7 default)")
        pooltype="multi"
        break
        ;;
    #"Single Volume (easier recovery)")
    "Single Volume")
        pooltype="single"
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
echo -e "You selected ${Cyan}${pooltype^} Volume${Off} storage pool"
echo


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
if [[ $single != "yes" ]] && [[ $raidtype != "raid1" ]]; then
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
# Ask user if they want to do a drive check

echo -e "Do you want perform a drive check? [y/n]"
read -r answer
if [[ ${answer,,} == "y" ]] || [[ ${answer,,} == "yes" ]]; then
    drivecheck="yes"
fi


#--------------------------------------------------------------------
# Let user confirm their choices

#if [[ $single == "yes" ]]; then
#    echo -en "Ready to create storage pool using ${Cyan}${mdisk[*]}${Off}"
#else
    #echo -en "\nReady to create ${Cyan}${raidtype^^}${Off} storage pool using "
    echo -en "\nReady to create ${Cyan}$raid${Off} storage pool using "
    echo -e "${Cyan}${mdisk[*]}${Off}"
#fi

if [[ $haspartitons == "yes" ]]; then
    echo -e "\n${Red}WARNING${Off} Everything on the selected"\
        "M.2 drive(s) will be deleted."
fi

echo -e "Type ${Cyan}yes${Off} to continue. Type anything else to quit."
read -r answer
if [[ ${answer,,} != "yes" ]]; then exit; fi


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
    setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" "$smp")"
    enabled=""
    if [[ ! $setting ]]; then
        # Add support_m2_pool="yes"
        echo 'support_m2_pool="yes"' >> "$synoinfo"
        enabled="yes"
    elif [[ $setting == "no" ]]; then
        # Change support_m2_pool="no" to "yes"
        #sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "$synoinfo"
        /usr/syno/bin/synosetkeyvalue "$synoinfo" "$smp" "yes"
        enabled="yes"
    elif [[ $setting == "yes" ]]; then
        echo -e "\nM.2 volume support already enabled."
    fi

    # Check if we enabled m2 volume support
    setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" "$smp")"
    if [[ $enabled == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            echo -e "\nEnabled M.2 volume support."
        else
            echo -e "\n${Error}ERROR${Off} Failed to enable M.2 volume support!"
        fi
    fi
fi

# Check if RAID F1 support is enabled
if [[ $raidtype == "raid_f1" ]]; then
    #if [[ $dsm72 == "yes" ]]; then
    if [[ $dsm71 == "yes" ]]; then
        srf1=support_diffraid
        setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" "$srf1")"
        enabled=""
        if [[ ! $setting ]]; then
            # Add support_diffraid="yes"
            echo 'support_diffraid="yes"' >> "$synoinfo"
            enabled="yes"
        elif [[ $setting == "no" ]]; then
            # Change support_diffraid="no" to "yes"
            #sed -i "s/${srf1}=\"no\"/${srf1}=\"yes\"/" "$synoinfo"
            /usr/syno/bin/synosetkeyvalue "$synoinfo" "$srf1" "yes"
            enabled="yes"
        elif [[ $setting == "yes" ]]; then
            echo -e "\nRAID F1 support already enabled."
        fi

        # Check if we enabled RAID F1 support
        setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" "$srf1")"
        if [[ $enabled == "yes" ]]; then
            if [[ $setting == "yes" ]]; then
                echo -e "\nEnabled RAID F1 support."
            else
                echo -e "\n${Error}ERROR${Off} Failed to enable RAID F1 support!"
            fi
        fi
    fi
fi


#--------------------------------------------------------------------
# Create storage pool on selected M.2 drives

# Single volume storage pool (DSM 6 style pool on md#)
# synostgpool --create -t single -l basic /dev/nvme0n1
# synostgpool --create -t single -l raid5 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1

# Multiple volume storage pool (DSM 7 style pool on vg#)
# synostgpool --create -l basic /dev/nvme0n1
# synostgpool --create -l raid5 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1


partargs=(  )
for i in "${mdisk[@]}"; do
   :
   partargs+=(
       /dev/"${i}"
   )
done

if [[ $pooltype == "single" ]]; then
    # Unset existing arguments
    while [[ $1 ]]; do shift; done
    # Set -t single arguments
    set -- "$@" "-t"
    set -- "$@" "single"
fi


echo -e "\nStarting creation of the storage pool."
if [[ $drivecheck != "yes" ]]; then
    /usr/syno/sbin/synostgpool --create "$@" -l "$raidtype" "${partargs[@]}"
    code="$?"
    if [[ $code -gt "0" ]] &&  [[ ! $code -eq "255" ]]; then
        #ding
        #echo "$code synostgpool failed to create storage pool!"
        echo "synostgpool return code: $code"
        #exit 1
    fi
else
    /usr/syno/sbin/synostgpool --create "$@" -l "$raidtype" -c "${partargs[@]}"
    code="$?"
    if [[ $code -gt "0" ]] &&  [[ ! $code -eq "255" ]]; then
        #ding
        #echo "$code synostgpool failed to create storage pool!"
        echo "synostgpool return code: $code"
        #exit 1
    fi
fi


#--------------------------------------------------------------------
# Notify of remaining steps

echo
showsteps  # Show the final steps to do in DSM

