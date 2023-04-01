# Synology M2 volume

<a href="https://github.com/007revad/Synology_M2_volume/releases"><img src="https://img.shields.io/github/release/007revad/Synology_M2_volume.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_M2_volume&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false"/></a>

### Description

Easily create an M.2 volume on Synology NAS without a lot of typing and no need for any how-to guides. And you ***don't*** need Synology branded NVMe drives.

This script will create the RAID and storage pool on your NVMe drive(s) for you so you can then create the volume in the DSM GUI.

All you have to do is run the script and type yes and 1, 2, 3 or 4 to answer some simple questions. Then reboot, go to Storage Manager, Online Assemable and Create Volume.

**RAID levels supported:**

| RAID Level  | Drives Required  |
| ----------- |------------------|
| Single      | 1 drive          |
| RAID 0      | 2 or more drives |
| RAID 1      | 2 or more drives |
| RAID 5      | 3 or more drives |

**Confirmed working on:**

| Model        | DSM version              | M.2 card |
| ------------ |--------------------------|----------|
| DS723+       | DSM 7.1.1-42962 Update 4 |          |
| DS3622xs+    | DSM 7.1.1-42962 Update 1 |          |
| DS1821+      | DSM 7.2-64216 Beta       |          |
| DS1821+      | DSM 7.2-64213 Beta       |          |
| DS1821+      | DSM 7.1.1-42962 Update 4 |          |
| DS1621+      | DSM 7.1.1-42962 Update 4 |          |
| DS1520+      | DSM 7.1.1-42962 Update 4 |          |
| DS920+       | DSM 7.1.1-42962 Update 1 |          |
| DS920+       | DSM 7.2-64216 Beta       |          |
| DS720+       | DSM 7.2 Beta             |          |
| DS1819+      | DSM 7.1.1                | M2D20    |
| DS1819+      | DSM 7.2 Beta             | M2D20    |
| DS1019+      | DSM 7.1.1-42962 Update 4 |          |
| DS918+       | DSM 7.1.1                |          |

### Important

If you later update DSM and your M.2 drives are shown as unsupported and the storage pool is shown as missing, and online assemble fails, you need to run the <a href="https://github.com/007revad/Synology_HDD_db">Synology_HDD_db</a> script. The <a href="https://github.com/007revad/Synology_HDD_db">Synology_HDD_db</a> script should run after every DSM update.

### To run the script

```YAML
sudo -i /volume1/scripts/syno_create_m2_volume.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

**Options:**
```YAML
  -a, --all        List all M.2 drives even if detected as active
  -s, --steps      Show the steps to do after running this script
  -h, --help       Show this help message
  -v, --version    Show the script version
```

It also has a dry run mode so you can see what it would have done had you run it for real.

<p align="center"><img src="/images/create-volume0.png"></p>

### What to do after running the script

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


