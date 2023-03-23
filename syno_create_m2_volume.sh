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
#-----------------------------------------------------------------------------------


# TODO 
# Allow specifying the size of the volume to leave unused space for drive wear management.
#
# Instead of creating the filesystem directly on the mdraid device, you can use LVM to create a PV on it,
# and a VG, and then use the UI to create volume(s), making it more "standard" to what DSM would do
#
# Physical Volume (PV): Consists of Raw disks or RAID arrays or other storage devices.
# Volume Group (VG): Combines the physical volumes into storage groups.
# Logical Volume (LV): VG's are divided into LV's and are mounted as partitions.
#
# Support SATA M.2 drives
# Maybe add logging
# Add option to repair damaged array


scriptver="v1.0.3"
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

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Show script version
echo -e "$script $scriptver\ngithub.com/$repo\n"

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)


echo -e "Type ${Cyan}yes${Off} to continue."\
    "Type anything else to do a ${Cyan}dry run test${Off}."
read -r answer
if [[ ${answer,,} != "yes" ]]; then dryrun="yes";\
    echo -e "Doing a dry run test\n"; fi


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
        echo -e "${Cyan}Do you want to download $tag now?${Off} {y/n]"
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
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "$scriptpath";
                        then
                            echo -e "${Error}ERROR ${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                        else
                            if ! rm "/tmp/$script-$shorttag.tar.gz"; then
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded $script-$shorttag.tar.gz!"
                            else
                                echo -e "\n$tag and changes.txt are in "\
                                    "${Cyan}$scriptpath/$script-$shorttag${Off}"
                                echo -e "${Cyan}Do you want to stop this script"\
                                    "so you can run the new one?${Off} {y/n]"
                                read -r -t 30 reply
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

#if cat /proc/mdstat | grep resync >/dev/null ; then  # useless cat
if grep resync /proc/mdstat >/dev/null ; then
    echo "The Synology is currently doing a RAID resync or data scrub!" >&2
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

    if grep -E "active.*${dev}" /proc/mdstat >/dev/null ; then
        echo -e "${Cyan}Skipping drive as it is being used by DSM${Off}" >&2
        #active="yes"
    else
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
    fi
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
# Select file system

PS3="Select the file system: "
select filesys in "btrfs" "ext4"; do
    case "$filesys" in
        btrfs)
            #echo -e "\nYou selected btrfs"  # debug
            format="btrfs"
            break
            ;;
        ext4)
            #echo -e "\nYou selected ext4"  # debug
            format="ext4"
            break
            ;;
        *) 
            echo -e "${Red}Invalid answer${Off}! Try again."
            ;;
    esac
done
echo


#--------------------------------------------------------------------
# Let user confirm their choices

if [[ $m22 ]]; then
    echo -e "Ready to create ${Cyan}RAID $raidtype $format${Off} volume"\
        "using ${Cyan}$m21${Off} and ${Cyan}$m22${Off}"
else
    echo -e "Ready to create ${Cyan}$format${Off} volume on ${Cyan}$m21${Off}"
fi

if [[ $haspartitons == "yes" ]]; then
    echo -e "\n${Red}WARNING${Off} Everything on the selected"\
        "M.2 drive(s) will be deleted."
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
    echo -e "\nCreating the RAID array. This can take 10 minutes or more..."
    if [[ $dryrun == "yes" ]]; then
        echo "mdadm --create /dev/md${nextmd} --level=${raidtype} --raid-devices=2"\
            "--force /dev/${m21}p3 /dev/${m22}p3"                # dryrun
    else
        mdadm --create /dev/md"${nextmd}" --level="${raidtype}" --raid-devices=2\
            --force /dev/"${m21}"p3 /dev/"${m22}"p3
    fi
    resyncsleep=5
else
    # I assume single drive is --level=1 --raid-devices=1 ?
    echo -e "\nCreating single drive device."
    if [[ $dryrun == "yes" ]]; then
        echo "mdadm --create /dev/md${nextmd} --level=1 --raid-devices=1"\
            "--force /dev/${m21}p3"                              # dryrun
    else
        mdadm --create /dev/md${nextmd} --level=1 --raid-devices=1\
            --force /dev/"${m21}"p3
    fi
    resyncsleep=30
fi

# Show resync progress every 30 seconds
while grep resync /proc/mdstat >/dev/null; do
    grep -E -A 2 active.*nvme /proc/mdstat | grep resync | cut -d"(" -f1
    sleep "$resyncsleep"
done


#--------------------------------------------------------------------
# Format the array

# Ensure mkfs.btrfs and mkfs.ext4 sees raid as SSD and optimises file system for SSD

if [[ $format == "btrfs" ]]; then
    if [[ $dryrun == "yes" ]]; then
        echo "echo 0 > /sys/block/md${nextmd}/queue/rotational"  # dryrun
        echo "mkfs.btrfs -f /dev/md${nextmd}"                    # dryrun
    else
        # Ensure mkfs.btrfs sees raid as SSD and optimises file system for SSD
        echo 0 > /sys/block/md${nextmd}/queue/rotational
        mkfs.btrfs -f /dev/md${nextmd}
    fi
elif [[ $format == "ext4" ]]; then
    if [[ $dryrun == "yes" ]]; then
        echo "echo 0 > /sys/block/md${nextmd}/queue/rotational"  # dryrun
        echo "mkfs.ext4 -f /dev/md${nextmd}"                     # dryrun
    else
        # Ensure mkfs.ext4 sees raid as SSD and optimises file system for SSD
        echo 0 > /sys/block/md${nextmd}/queue/rotational  # Is this valid for mkfs.ext4 ?
        mkfs.ext4 -F /dev/md${nextmd}
    fi
else
    echo "What file system did you select!?"; exit
fi


#--------------------------------------------------------------------
# Notify of remaining steps

echo -e "\nAfter the restart go to Storage Manager and select online assemble:"
echo -e "  ${Cyan}Storage Pool > Available Pool > Online Assemble${Off}"

echo -e "Then, optionally, enable TRIM:"
echo -e "  ${Cyan}Storage Pool > ... > Settings > SSD TRIM${Off}"


#--------------------------------------------------------------------
# Reboot

echo -e "\nThe Synology needs to restart."
echo -e "Type ${Cyan}yes${Off} to reboot now."
echo -e "Type anything else to quit (if you will restart it yourself)."
read -r answer
if [[ ${answer,,} != "yes" ]]; then exit; fi
if [[ $dryrun == "yes" ]]; then
    echo "reboot"  # dryrun
else
    # Reboot in the background so user can DSM's "shutting down" message
    #reboot &  # not working
    reboot
fi


#exit  # Don't exit so user can DSM's "shutting down" message

