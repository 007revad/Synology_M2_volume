# Synology M2 volume

<a href="https://github.com/007revad/Synology_M2_volume/releases"><img src="https://img.shields.io/github/release/007revad/Synology_M2_volume.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_M2_volume&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false"/></a>

### Description

Easily create an M.2 volume on Synology NAS without a lot of typing and no need for any how-to guides.

This script will create a volume on your NVMe drive(s) for you. All you have to do is run the script and type yes and 1, 2, 3 or 4 to answer some simple questions.

It also has a dry run mode so you can see what it would have done had you run it for real.

<p align="center"><img src="/images/create_m2_volume_dryrun.png"></p>

### What to do after running the script

1. Restart the Synology NAS.
2. Go to Storage Manager and select online assemble:
    - Storage Pool > Available Pool > Online Assemble
3. Optionally enable TRIM:
    - Storage Pool > ... > Settings > SSD TRIM

<p align="center">Available Storage Pool</p>
<p align="center"><img src="/images/create_m2_volume_available_pool.png"></p>

<p align="center">Online Assemble step 1</p>
<p align="center"><img src="/images/create_m2_volume_online_assemble.png"></p>

<p align="center">Online Assemble step 2</p>
<p align="center"><img src="/images/create_m2_volume_online_assemble2.png"></p>

<p align="center">Success!</p>
<p align="center"><img src="/images/create_m2_volume_success.png"></p>

<p align="center">Enable TRIM</p>
<p align="center"><img src="/images/create_m2_volume_enable_trim.png"></p>


