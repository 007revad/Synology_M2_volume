# Synology M2 volume

<a href="https://github.com/007revad/Synology_M2_volume/releases"><img src="https://img.shields.io/github/release/007revad/Synology_M2_volume.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_M2_volume&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false"/></a>

### Description

Easily create an M.2 volume on Synology NAS without a lot of typing and no need for any how-to guides. 

This script will create the RAID and storage pool on your NVMe drive(s) for you so you can then create the volume in the DSM GUI.

All you have to do is run the script and type yes and 1, 2, 3 or 4 to answer some simple questions. Then reboot, go to Storage Manager, Online Assemable and Create Volume.

Confirmed working on:
- DS1821+ DSM 7.2 Beta
- DS1621+ DSM 7.1.1-42962 Update 4
- DS920+ DSM 7.1.1-42962 Update 1
- DS720+ DSM 7.2 Beta
- DS918+ DSM 7.1.1


### To run the script ###

```YAML
sudo i /volume1/scripts/create_m2_volume.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

It also has a dry run mode so you can see what it would have done had you run it for real.

<p align="center"><img src="/images/create-volume0.png"></p>

### What to do after running the script

1. Restart the Synology NAS.
2. Go to Storage Manager and select Online Assemble:
    - Storage Pool > Available Pool > Online Assemble
3. Create the volume:
    - Select the new Storage Pool > Create > Create Volume
4. Set the allocated size to max, or 7% less for overprovisioning.
5. Optionally enter a volume description. Be creative :)
    - Click Next
6. Select the file system: Btrfs or ext4.
    - Click Next and you've finished creating your volume.
7. Optionally enable and schedule TRIM:
    - Storage Pool > ... > Settings > SSD TRIM

<p align="center">Storage Pool available for online assembly</p>
<p align="center"><img src="/images/create_m2_volume_available_pool.png"></p>

<p align="center">Online Assemble step 1</p>
<p align="center"><img src="/images/create_m2_volume_online_assemble.png"></p>

<p align="center">Online Assemble step 2</p>
<p align="center"><img src="/images/create_m2_volume_online_assemble2.png"></p>

<p align="center">Create Volume</p>
<p align="center"><img src="/images/create-volume1.png"></p>

<p align="center">Allocate volume capacity</p>
<p align="center"><img src="/images/create-volume2.png"></p>

<p align="center">Volume description</p>
<p align="center"><img src="/images/create-volume3.png"></p>

<p align="center">Select file system</p>
<p align="center"><img src="/images/create-volume4.png"></p>

<p align="center">Success!</p>
<p align="center"><img src="/images/create-volume5.png"></p>

<p align="center">Enable TRIM</p>
<p align="center"><img src="/images/create_m2_volume_enable_trim.png"></p>


