#!/usr/bin/env bash

scriptver="v10.0.0"
script=Synology_M2_volume_test
#repo="007revad/Synology_M2_volume"
#scriptname=syno_create_m2_volume_test

# Shell Colors
Red='\e[0;31m'      # ${Red}
Yellow='\e[0;33m'  # ${Yellow}
Cyan='\e[0;36m'     # ${Cyan}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

ding(){ 
    printf \\a
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


#--------------------------------------------------------------------
# Get list of M.2 drives

getm2info(){ 
    local nvme
    local vendor
    local pcislot
    local cardslot
    nvmemodel=$(cat "$1/device/model")
    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading/trailing space

    vendor=$(synonvme --vendor-get "/dev/$(basename -- "${1}")")
    vendor=" $(printf "%s" "$vendor" | cut -d":" -f2 | xargs)"
    nvme=$(synonvme --get-location "/dev/$(basename -- "${1}")")


echo "nvme: $nvme"    # debug


    if [[ ! $nvme =~ "PCI Slot: 0" ]]; then
        pcislot="$(echo "$nvme" | cut -d"," -f2 | awk '{print $NF}')-"
    fi
    cardslot="$(echo "$nvme" | awk '{print $NF}')"


echo "pcislot: $pcislot"    # debug
echo "cardslot: $cardslot"  # debug


    #echo "$2 M.2 $(basename -- "${1}") is $nvmemodel" >&2
    echo "$(basename -- "${1}") M.2 Drive $pcislot$cardslot -$vendor $nvmemodel" >&2
    dev="$(basename -- "${1}")"

    echo "/dev/${dev}" >&2  # debug

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
    #m2list+=("${dev}")
    m2list+=("M.2 Drive $pcislot$cardslot")
    m2list_assoc["M.2 Drive $pcislot$cardslot"]="$dev"
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

if [[ ${#m2list[@]} == "0" ]]; then exit; fi


echo -e "\nm2list:"           # debug
for i in "${m2list[@]}"; do  # debug
    echo "$i"                 # debug
done                          # debug

echo -e "\nm2list_assoc:"           # debug
for i in "${m2list_assoc[@]}"; do  # debug
    echo "$i"                       # debug
done                                # debug


exit  # debug

