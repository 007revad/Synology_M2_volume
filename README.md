# Synology M2 volume

<a href="https://github.com/007revad/Synology_M2_volume/releases"><img src="https://img.shields.io/github/release/007revad/Synology_M2_volume.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_M2_volume&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

Easily create an M.2 volume on Synology NAS without a lot of typing and no need for any how-to guides. And you ***don't*** need Synology branded NVMe drives.

- **DSM 7** This script creates the RAID and storage pool on your NVMe drive(s) so you can then create the volume in the DSM GUI.
- **DSM 6** This script creates the RAID, storage pool and volume on your NVMe drive(s) for you.

All you have to do is run the script and type yes and 1, 2, 3 or 4 to answer some simple questions. Then reboot, go to Storage Manager, Online Assemble and Create Volume.

It also allows you to create a storage pool/volume spanning internal NVMe drives and NVMe drives in a Synology M.2 PCIe card.

For Xpenology users the script supports an unlimited number of NVMe drives for RAID 0, 5, 6 and 10.

### RAID levels supported

| RAID Level  | Drives Required  | Maximum Drives |
| ----------- |------------------|----------------|
| Single      | 1 drive          | 1 drive        |
| RAID 0      | 2 or more drives | Unlimited      |
| RAID 1      | 2 or more drives | 4 drives       |
| RAID 5      | 3 or more drives | Unlimited      |
| RAID 6      | 4 or more drives | Unlimited      |
| RAID 10     | 4 or more drives | Unlimited      |

### Confirmed working on

<details>
  <summary>Click here to see list</summary>

| Model        | DSM version              | M.2 card  | Notes           |
| ------------ |--------------------------|-----------|-----------------|
| RS2423+      | DSM 7.2-64570 Update 1   |           |
| DS1823xs+    | DSM 7.2-64561            | M2D20     |
| DS923+       | DSM 7.2.1-69057 Update 2 |           |
| DS923+       | DSM 7.1.1-42962 Update 5 |           |
| DS723+       | DSM 7.2.1-69057 Update 3 |           |
| DS723+       | DSM 7.2-64570 Update 1   |           |
| DS723+       | DSM 7.1.1-42962 Update 4 |           |
| DS423+       | DSM 7.2.1-69057 Update 3 |           |
| DS423+       | DSM 7.2-64570 Update 3   |           |
| DS423+       | DSM 7.1.1-42962 Update 4 |           |
| DS3622xs+    | DSM 7.2-64216 Beta       | E10M20-T1 |
| DS3622xs+    | DSM 7.1.1-42962 Update 1 |           |
| DS1522+      | DSM 7.2-64570            |           |
| DS1522+      | DSM 7.1.1-42962 Update 4 |           |
| DS1821+      | DSM 7.2.1-69057 Update 3 |           |
| DS1821+      | DSM 7.2.1-69057 Update 2 |           |
| DS1821+      | DSM 7.2.1-69057 Update 1 |           |
| DS1821+      | DSM 7.2.1-69057          |           |
| DS1821+      | DSM 7.2-64570 Update 3   |           |
| DS1821+      | DSM 7.2-64570 Update 1   | E10M20-T1 | Also needs [Synology enable_M2_card](https://github.com/007revad/Synology_enable_M2_card) |
| DS1821+      | DSM 7.2-64570 Update 1   | M2D18     | Also needs [Synology enable_M2_card](https://github.com/007revad/Synology_enable_M2_card) |
| DS1821+      | DSM 7.2-64570 Update 1   |           |
| DS1821+      | DSM 7.2-64570            |           |
| DS1821+      | DSM 7.2-64561            |           |
| DS1821+      | DSM 7.2-64216 Beta       |           |
| DS1821+      | DSM 7.2-64213 Beta       |           |
| DS1821+      | DSM 7.1.1-42962 Update 4 |           |
| DS1821+      | **DSM 6.2.4**-25556 Update 7 |           |
| DS1621+      | DSM 7.2-64570 Update 1   | E10M20-T1 | Also needs [Synology enable_M2_card](https://github.com/007revad/Synology_enable_M2_card) |
| DS1621+      | DSM 7.2-64570 Update 1   |           |
| DS1621+      | DSM 7.1.1-42962 Update 4 |           |
| RS1221+      | DSM 7.2-64570 Update 1   | E10M20-T1 |
| RS1221+      | DSM 7.1.1                | E10M20-T1 |
| DS1520+      | DSM 7.2.1-69057 Update 2 |           |
| DS1520+      | DSM 7.2-64570 Update 1   |           |
| DS1520+      | DSM 7.1.1-42962 Update 4 |           |
| DS920+       | DSM 7.2.1-69057 Update 3 |           |
| DS920+       | DSM 7.2.1-69057 Update 2 |           |
| DS920+       | DSM 7.2.1-69057 update 1 |           |
| DS920+       | DSM 7.2.1-69057          |           |
| DS920+       | DSM 7.2-64570 Update 1   |           |
| DS920+       | DSM 7.2-64561            |           |
| DS920+       | DSM 7.2-64216 Beta       |           |
| DS920+       | DSM 7.1.1-42962 Update 1 |           |
| DS920+       | **DSM 6**                |           |
| DS918+       | DSM 7.2-64570 Update 3   |           |
| RS820+       | DSM 7.2-64570 Update 3   | M2D20     |
| DS720+       | DSM 7.2.1-69057 Update 3 |           |
| DS720+       | DSM 7.2.1-69057 Update 1 |           |
| DS720+       | DSM 7.2.1-69057          |           |
| DS720+       | DSM 7.2-64570 Update 3   |           |
| DS720+       | DSM 7.2-64570 Update 1   |           |
| DS720+       | DSM 7.2-64570            |           |
| DS720+       | DSM 7.2-64561            |           |
| DS720+       | DSM 7.2-64216 Beta       |           |
| DS720+       | **DSM 6.2.4**            |           |
| DS420+       | DSM 7.2-64570 Update 1   |           |
| DS1819+      | DSM 7.2-64216 Beta       | M2D20     |
| DS1819+      | DSM 7.1.1                | M2D20     |
| DS1019+      | DSM 7.2.1-69057 Update 2 |           |
| DS1019+      | DSM 7.2-64561            |           |
| DS1019+      | DSM 7.1.1-42962 Update 4 |           |
| DS1618+      | DSM 7.1.1                | M2D18     |
| DS918+       | DSM 7.2-64561            |           |
| DS918+       | DSM 7.1.1                |           |
| DS3617xs     | DSM 7.2-64570            | M2D20     |

</details>

### Important

If you later update DSM and your M.2 drives are shown as unsupported and the storage pool is shown as missing, and online assemble fails, you need to run the <a href="https://github.com/007revad/Synology_HDD_db">Synology_HDD_db</a> script. The <a href="https://github.com/007revad/Synology_HDD_db">Synology_HDD_db</a> script should run after every DSM update.

### Download the script

See <a href=images/how_to_download_generic.png/>How to download the script</a> for the easiest way to download the script.

### Video guide

Vikash has created a step by step YouTube video here: https://www.youtube.com/watch?v=sclQprHsXQE

### To run the script via SSH

[How to enable SSH and login to DSM via SSH](https://kb.synology.com/en-global/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet)

```YAML
sudo -i /volume1/scripts/syno_create_m2_volume.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

### Troubleshooting

If the script won't run check the following:

1. If the path to the script contains any spaces you need to enclose the path/scriptname in double quotes:
   ```YAML
   sudo -i "/volume1/my scripts/syno_create_m2_volume.sh"
   ```
2. Make sure you unpacked the zip or rar file that you downloaded and are trying to run the syno_create_m2_volume.sh file.
3. Set the syno_create_m2_volume.sh file as executable:
   ```YAML
   sudo chmod +x "/volume1/scripts/syno_create_m2_volume.sh"
   ```

### Options:
```YAML
  -a, --all        List all M.2 drives even if detected as active
  -s, --steps      Show the steps to do after running this script
  -h, --help       Show this help message
  -v, --version    Show the script version
```

It also has a dry run mode so you can see what it would have done had you run it for real.

<p align="center"><img src="/images/create-volume0.png"></p>

### What to do after running the script

**DSM 7**
1. Restart the Synology NAS.
2. Go to Storage Manager and select Online Assemble:
    - Storage Pool > Available Pool > Online Assemble
3. Create the volume as you normally would:
    - Select the new Storage Pool > Create > Create Volume.
    - Set the allocated size.
      - Optionally enter a volume description. Be creative :)
    - Click Next.
    - Select the file system (Btrfs or ext4) and click Next.
    - Optionally enable *Encrypt this volume* and click Next.
      - Create an encryption password or enter your existing encryption password. 
    - Confirm your settings and click Apply to finish creating your M.2 volume.
4. Optionally enable and schedule TRIM:
    - Storage Pool > ... > Settings > SSD TRIM    
    - **Note: DSM 7.1.1. has no SSD TRIM setting for M.2 storage pools**
    - **Note: DSM 7.2 Beta has no SSD TRIM setting for M.2 RAID 0 or RAID 5**

**DSM 6**
1. Restart the Synology NAS.

### DSM 7 screen shots

<p align="center">Storage Pool available for Online Assemble</p>
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


