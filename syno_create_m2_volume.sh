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
# Change to not include the 1st selected drive in the choices for 2nd drive.
# Better detection if DSM is using the drive.
# Show drive names the same as DSM does.
# Support SATA M.2 drives.
# Maybe add logging.
# Add option to repair damaged array.

# DONE
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


scriptver="v1.1.6"
script=Synology_M2_volume
repo="007revad/Synology_M2_volume"

#echo -e "bash version: $(bash --version | head -1 | cut -d' ' -f4)\n"  # debug

# Shell Colors
#Black='\e[0;30m'   # ${Black}
Red='\e[0;31m'      # ${Cyan}
#Green='\e[0;32m'   # ${Green}
#Yellow='\e[0;33m'  # ${Yellow}
#Blue='\e[0;34m'    # ${Blue}
#Purple='\e[0;35m'  # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'   # ${White}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}


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
}


scriptversion(){
    cat <<EOF
$script $scriptver - by 007revad

See https://github.com/$repo
EOF
}


showsteps(){
    echo -e "${Cyan}Steps you need to do after running this script:${Off}"
    major=$(get_key_value /etc.defaults/VERSION major)
    minor=$(get_key_value /etc.defaults/VERSION major)
    if [[ $major -gt "6" ]]; then
        cat <<EOF
  1. After the restart go to Storage Manager and select online assemble:
       Storage Pool > Available Pool > Online Assemble
  2. Create the volume as you normally would:
       Select the new Storage Pool > Create > Create Volume
  3. Optionally enable TRIM:
       Storage Pool > ... > Settings > SSD TRIM
EOF
    else
        cat <<EOF
  1. After the restart go to Storage Manager and select online assemble:
       Storage Pool > Available Pool > Online Assemble
  2. Optionally enable TRIM:
       Storage Pool > ... > Settings > SSD TRIM
EOF
    fi
    #return
}


# Check for flags with getopt
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
                exit
                ;;
            -v|--version)       # Show script version
                scriptversion
                exit
                ;;
            -l|--log)            # Log
                log=yes
                ;;
            --debug)            # Show and log debug info
                debug=yes
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                echo "Invalid option '$1'"
                usage "$1"
                ;;
        esac
        shift
    done
fi


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM major and minor versions
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
dsminor=$(get_key_value /etc.defaults/VERSION minorversion)
if [[ $dsm -gt "6" ]] && [[ $dsminor -gt "1" ]]; then
    dsm72="yes"
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)

# Get DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
echo -e "$model DSM $productversion-$buildnumber $buildphase\n"


echo -e "Type ${Cyan}yes${Off} to continue."\
    "Type anything else to do a ${Cyan}dry run test${Off}."
read -r answer
if [[ ${answer,,} != "yes" ]]; then dryrun="yes";\
    echo -e "Doing a dry run test\n"; else echo; fi


#------------------------------------------------------------------------------
# Check latest release with GitHub API

get_latest_release() {
    # Curl timeout options:
    # https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
    curl --silent -m 10 --connect-timeout 5 \
        "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |          # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # Pluck JSON value
}

tag=$(get_latest_release "$repo")
shorttag="${tag:1}"
scriptpath=$(dirname -- "$0")

if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check --version-sort &> /dev/null ; then
    echo -e "${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    if [[ -f $scriptpath/$script-$shorttag.tar.gz ]]; then
        # They have the latest version tar.gz downloaded but are using older version
        echo "https://github.com/$repo/releases/latest"
        sleep 10
    elif [[ -d $scriptpath/$script-$shorttag ]]; then
        # They have the latest version extracted but are using older version
        echo "https://github.com/$repo/releases/latest"
        sleep 10
    else
        echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
        read -r -t 30 reply
        if [[ ${reply,,} == "y" ]]; then
            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -LJO -m 30 --connect-timeout 5 "$url";
                then
                    echo -e "${Error}ERROR ${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to script location
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; 
                        then
                            echo -e "${Error}ERROR ${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                        else
                            # Copy new files to script location
                            cp "/tmp/$script-$shorttag/CHANGES.txt" "$scriptpath"
                            cp "/tmp/$script-$shorttag/"*.sh "$scriptpath"

                            # Delete downloaded .tar.gz file
                            if ! rm "/tmp/$script-$shorttag.tar.gz"; then
                                delerr=1
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag.tar.gz!"
                            fi
                            # Delete extracted tmp files
                            if ! rm -r "/tmp/$script-$shorttag"; then
                                delerr=1
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag!"
                            fi
                            if [[ $delerr != 1 ]]; then
                                echo -e "\n$tag and changes.txt downloaded to:"\
                                    "$scriptpath"
                                echo -e "${Cyan}Do you want to stop this script"\
                                    "so you can run the new one?${Off} [y/n]"
                                read -r reply
                                if [[ ${reply,,} == "y" ]]; then exit; fi
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR ${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                    fi
                fi
            else
                echo -e "${Error}ERROR ${Off} Failed to cd to /tmp!"
            fi
        fi
    fi
fi


#--------------------------------------------------------------------
# Check there's no active resync

if grep resync /proc/mdstat >/dev/null ; then
    echo "The Synology is currently doing a RAID resync or data scrub!"
    exit
fi


#--------------------------------------------------------------------
# Get list of M.2 drives

getm2info() {
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
        nvme*)  # M.2 NVMe drives (in PCIe card only?)
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

#echo -e "NVMe list: '${m2list[@]}'\n"  # debug
#echo -e "NVMe qty: ${#m2list[@]}\n"    # debug

if [[ ${#m2list[@]} == "0" ]]; then exit; fi


#--------------------------------------------------------------------
# Select RAID type (if multiple M.2 drives found)

if [[ ${#m2list[@]} -gt "1" ]]; then
    PS3="Select the RAID type: "
    options=("Single" "RAID 0" "RAID 1" "Quit")
    select raid in "${options[@]}"; do
      case "$raid" in
        "Single")
          #echo -e "\nYou selected Single"  # debug
          raidtype="1"
          single="yes"
          break
          ;;
        "RAID 0")
          #echo -e "\nYou selected RAID 0"  # debug
          raidtype="0"
          break
          ;;
        "RAID 1")
          #echo -e "\nYou selected RAID 1"  # debug
          raidtype="1"
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
    echo
elif [[ ${#m2list[@]} -eq "1" ]]; then
    raidtype="1"
    single="yes"
fi


#--------------------------------------------------------------------
# Select first M.2 drive

getindex(){
    # Get array index from value
    for i in "${!m2list[@]}"; do
        if [[ "${m2list[$i]}" == "${1}" ]]; then
            r="${i}"
        fi
    done
    return "$r"
}

if [[ $single == "yes" ]]; then
    PS3="Select the M.2 drive: "
elif [[ $raidtype == "0" ]] || [[ $raidtype == "1" ]]; then
    PS3="Select the first M.2 drive: "
fi
#select nvmes in "nvme0" "nvme1" "Quit"; do  # test
select nvmes in "${m2list[@]}" "Quit"; do
    #qty="${#m2list[@]}"
    case "$nvmes" in
        nvme0n1)
            for i in "${!m2list[@]}"; do  # Get array index from element
                if [[ "${m2list[$i]}" == "nvme0n1" ]]; then
                    m21="${m2list[i]}"
                fi
            done
            break
            ;;
        nvme1n1)
            for i in "${!m2list[@]}"; do
                if [[ "${m2list[$i]}" == "nvme1n1" ]]; then
                    m21="${m2list[i]}"
                fi
            done
            break
            ;;
        nvme2n1)
            for i in "${!m2list[@]}"; do
                if [[ "${m2list[$i]}" == "nvme2n1" ]]; then
                    m21="${m2list[i]}"
                fi
            done
            break
            ;;
        nvme3n1)
            for i in "${!m2list[@]}"; do
                if [[ "${m2list[$i]}" == "nvme3n1" ]]; then
                    m21="${m2list[i]}"
                fi
            done
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
#echo -e "\nYou selected $m21"  # debug
echo


#--------------------------------------------------------------------
# Select second M.2 drive (if RAID selected)

if [[ $single != "yes" ]]; then
    if [[ $raidtype == "0" ]] || [[ $raidtype == "1" ]]; then
        PS3="Select the second M.2 drive: "
        #select nvmes in "nvme0" "nvme1" "Quit"; do  # debug
        select nvmes in "${m2list[@]}" "Quit"; do
            case "$nvmes" in
                nvme0n1)
                    for i in "${!m2list[@]}"; do  # Get array index from element
                        if [[ "${m2list[$i]}" == "nvme0n1" ]]; then
                            m22="${m2list[i]}"
                        fi
                    done
                    if [[ $m21 == "$m22" ]]; then
                        echo "You selected $m21 twice! Try again."
                    else
                        #echo -e "\nYou selected ${m2list[0]}"  # debug
                        break
                    fi
                    ;;
                nvme1n1)
                    for i in "${!m2list[@]}"; do
                        if [[ "${m2list[$i]}" == "nvme1n1" ]]; then
                            m22="${m2list[i]}"
                        fi
                    done
                    if [[ $m21 == "$m22" ]]; then
                        echo "You selected $m21 twice! Try again."
                    else
                        #echo -e "\nYou selected ${m2list[1]}"  # debug
                        break
                    fi
                    ;;
                nvme2n1)
                    for i in "${!m2list[@]}"; do
                        if [[ "${m2list[$i]}" == "nvme2n1" ]]; then
                            m22="${m2list[i]}"
                        fi
                    done
                    if [[ $m21 == "$m22" ]]; then
                        echo "You selected $m21 twice! Try again."
                    else
                        #echo -e "\nYou selected ${m2list[2]}"  # debug
                        break
                    fi
                    ;;
                nvme3n1)
                    for i in "${!m2list[@]}"; do
                        if [[ "${m2list[$i]}" == "nvme3n1" ]]; then
                            m22="${m2list[i]}"
                        fi
                    done
                    if [[ $m21 == "$m22" ]]; then
                        echo "You selected $m21 twice! Try again."
                    else
                        #echo -e "\nYou selected ${m2list[3]}"  # debug
                        break
                    fi
                    ;;
                Quit)
                    exit
                    ;;
                *) 
                    echo -e "${Red}Invalid answer${Off}! Try again."
                    ;;
            esac
        done
        echo
    fi
fi


#--------------------------------------------------------------------
# Let user confirm their choices

if [[ $m22 ]]; then
    echo -e "Ready to create ${Cyan}RAID $raidtype${Off} volume"\
        "group using ${Cyan}$m21${Off} and ${Cyan}$m22${Off}"
else
    echo -e "Ready to create volume group on ${Cyan}$m21${Off}"
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
echo -e "You chose to continue. You are brave! :)\n"  # debug
sleep 3


#--------------------------------------------------------------------
# Get highest md# mdraid device

# Using "md[0-9]{1,2}" to avoid md126 and md127 etc
lastmd=$(grep -oP "md[0-9]{1,2}" "/proc/mdstat" | sort | tail -1)
nextmd=$(("${lastmd:2}" +1))
echo "Using md$nextmd as it's the next available."  # debug


#--------------------------------------------------------------------
# Create Synology partitions on selected M.2 drives

if [[ $dsm == "7" ]]; then
    synopartindex=13  # Syno partition index for NVMe drives can be 12 or 13 or ?
else
    synopartindex=12  # Syno partition index for NVMe drives can be 12 or 13 or ?
fi
if [[ $m21 ]]; then
    echo -e "\nCreating Synology partitions on $m21"
    if [[ $dryrun == "yes" ]]; then
        echo "synopartition --part /dev/$m21 $synopartindex"  # dryrun
    else
        synopartition --part /dev/"$m21" "$synopartindex"
    fi
fi
if [[ $m22 ]]; then
    echo -e "\nCreating Synology partitions on $m22"
    if [[ $dryrun == "yes" ]]; then
        echo "synopartition --part /dev/$m22 $synopartindex"  # dryrun
    else
        synopartition --part /dev/"$m22" "$synopartindex"
    fi
fi
if [[ $m23 ]]; then
    echo -e "\nCreating Synology partitions on $m23"
    if [[ $dryrun == "yes" ]]; then
        echo "synopartition --part /dev/$m23 $synopartindex"  # dryrun
    else
        synopartition --part /dev/"$m23" "$synopartindex"
    fi
fi
if [[ $m24 ]]; then
    echo -e "\nCreating Synology partitions on $m24"
    if [[ $dryrun == "yes" ]]; then
        echo "synopartition --part /dev/$m24 $synopartindex"  # dryrun
    else
        synopartition --part /dev/"$m24" "$synopartindex"
    fi
fi


#--------------------------------------------------------------------
# Create the RAID array: --level=1 for RAID 1, or --level=0 for RAID 0

#if [[ $raidtype ]]; then
if [[ $m21 ]] && [[ $m22 ]]; then
    echo -e "\nCreating the RAID array. This can take an hour..."
    if [[ $dryrun == "yes" ]]; then
        echo "mdadm --create /dev/md${nextmd} --level=${raidtype} --raid-devices=2"\
            "--force /dev/${m21}p3 /dev/${m22}p3"                # dryrun
    else
        mdadm --create /dev/md"${nextmd}" --level="${raidtype}" --raid-devices=2\
            --force /dev/"${m21}"p3 /dev/"${m22}"p3
    fi
else
    echo -e "\nCreating single drive RAID."
    if [[ $dryrun == "yes" ]]; then
        echo "mdadm --create /dev/md${nextmd} --level=1 --raid-devices=1"\
            "--force /dev/${m21}p3"                              # dryrun
    else
        mdadm --create /dev/md${nextmd} --level=1 --raid-devices=1\
            --force /dev/"${m21}"p3
    fi
fi

# Show resync progress every 5 seconds
while grep resync /proc/mdstat >/dev/null; do
    # Only multi-drive RAID gets re-synced
    progress="$(grep -E -A 2 active.*nvme /proc/mdstat | grep resync | cut -d\( -f1 )"
    echo -ne "$progress\r"
    sleep 5
done
# Show 100% progress
if [[ $m21 ]] && [[ $m22 ]]; then
    echo -ne "      [=====================]  resync = 100%\r"
fi


#--------------------------------------------------------------------
# Create Physical Volume and Volume Group with LVM

# Create a physical volume (PV) on the partition
echo -e "\nCreating a physical volume (PV) on md$nextmd partition"
if [[ $dryrun == "yes" ]]; then
    #echo "pvcreate /dev/md$nextmd"                                 # dryrun
    echo "pvcreate -ff /dev/md$nextmd"                              # dryrun
else
    #pvcreate /dev/md$nextmd
    pvcreate -ff /dev/md$nextmd
fi

# Create a volume group (VG)
echo -e "\nCreating a volume group (VG) on md$nextmd partition"
if [[ $dryrun == "yes" ]]; then
    echo "vgcreate vg$nextmd /dev/md$nextmd"                        # dryrun
else
    vgcreate vg$nextmd /dev/md$nextmd
fi


#--------------------------------------------------------------------
# Enable m2 volume support - DSM 7.2 and later only

# Backup synoinfo.conf if needed
if [[ $dsm72 == "yes" ]]; then
    synoinfo="/etc.defaults/synoinfo.conf"
    if [[ ! -f ${synoinfo}.bak ]]; then
        if cp "$synoinfo" "$synoinfo.bak"; then
            echo -e "\nBacked up $(basename -- "$synoinfo")" >&2
        else
            echo -e "\n${Error}ERROR 5${Off} Failed to backup $(basename -- "$synoinfo")!"
            exit 1
        fi
    fi
fi

# Check if m2 volume support is enabled
if [[ $dsm72 == "yes" ]]; then
    smp=support_m2_pool
    setting="$(get_key_value "$synoinfo" "$smp")"
    enabled=""
    if [[ ! $setting ]]; then
        # Add support_m2_pool"yes"
        echo 'support_m2_pool="yes"' >> "$synoinfo"
        enabled="yes"
    elif [[ $setting == "no" ]]; then
        # Change support_m2_pool"no" to "yes"
        sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "$synoinfo"
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

echo -e "\n${Cyan}The Synology needs to restart.${Off}"
echo -e "Type ${Cyan}yes${Off} to reboot now."
echo -e "Type anything else to quit (if you will restart it yourself)."
read -r answer
if [[ ${answer,,} != "yes" ]]; then exit; fi
if [[ $dryrun == "yes" ]]; then
    echo "reboot"  # dryrun
else
    # Reboot in the background so user can see DSM's "going down" message
    reboot &
fi


#exit  # Don't exit so user can DSM's "shutting down" message

