# <div align="center">LDOS v1.30 (Leonard Demo Operating System)</div>

## Introduction
LDOS is a framework to easily build Amiga multi-part demos. You can chain several amiga executable effects. LDOS is managing memory allocation, floppy disk loading, data depacking and image disk creation. LDOS also includes an HDD loader to run your demo from harddisk. LDOS toolchain is running on Windows platform.

[Please like on your lovely Pouet website :)](https://www.pouet.net/prod.php?which=89822)

## Demo sample
LDOS repository also comes with a demo sample so you can see how to use LDOS in real life application. Just run demo/build.cmd to build the sample LDOS demo. It will produce "ldos_demo.adf" file. You can use it in any Amiga emulator or write on real floppy and test on real hardware.
The sample demo is made of 3 files (look at demo/script.txt)
1. parcade.mod ( mod music file )
2. Sprite loader: few animated sprites during the loading & depacking of the second part
3. Greetings: large bitmap scroll (fun fact: this part is a conversion of Greetings part of Atari ["We Were @" demo](https://www.pouet.net/prod.php?which=66702) )

## Building LDOS
LDOS comes with pre-assembled binaries. ( ldos/bin ). But if you want to modify & build yourself, just run ldos/src/build.cmd

## How to use LDOS
Each of your demo FX should include LDOS header
```c
      include "../../ldos/kernel.inc"
```
Each LDOS function is called using JSR. For instance, if you want to pre-load the next FX from floppy disk, just do:
```c
			move.l  (LDOS_BASE).w,a6
			jsr LDOS_PRELOAD_NEXT_FX(a6)
```
You can open ldos/kernel.inc to see all LDOS functions

Each demo part should be a standard Amiga executable.

## LDOS Technical details
* LDOS should run on any Amiga ( from A500 to 060 )
* LDOS is primary made for A500 demo. If ran on higger amiga, CPU caches are switched off
* Generated demo is 1MiB RAM targeted ( with at least 512KiB of chip memory )
* Use ARJ mode 7 packer
* LDOS is loading & depacking at the same time. Most of demos are loading, then depacking. LDOS depacks while loading, so basically depacking time is free.
* LDOS use Light Speed Player (fastest MOD player ever)
* Just put all the exe of your demo in a script.txt and run ldos/bin/install ( look at demo/build.cmd script )
* All files are automatically packed using Arj7, you don't have to worry about packing
* fun fact: All data on the disk is packed except the small bootblock code
* LDOS bootblock is 292 bytes only and contains the only unpacked data of the disk. Packed data (including FAT) starts right after these 292 bytes
* LDOS cluster size is 2 bytes only ( no 512 bytes waste per file :) )

## Credits

* LDOS is written by Arnaud Carré aka Leonard/Oxygene ( [@leonard_coder](https://twitter.com/leonard_coder) )
* ARJ depackers by Mr Ni! / TOS-crew
* Light Speed Player by Leonard/Oxygene (https://github.com/arnaud-carre/LSPlayer)
* LDOS v1.02 used P61 music player by Photon/Scoopex

## Amiga demos using LDOS
LDOS is production ready :) Several Amiga demos are already powered by LDOS:

### The Fall by The Deadliners & Lemon. (1st place at Revision 2018, Amiga compo)
https://www.pouet.net/prod.php?which=75773

![The Fall](https://content.pouet.net/files/screenshots/00075/00075773.png)

### De Profundis by The Deadliners & Lemon. & Oxygene (2nd place at Revision 2019, Amiga compo)
https://www.pouet.net/prod.php?which=81081

![De Profundis](https://content.pouet.net/files/screenshots/00081/00081081.jpg)

### AmigAtari by Oxygene (3rd place at Revision 2020, Wild compo)
https://www.pouet.net/prod.php?which=85276

![AmigAtari](https://content.pouet.net/files/screenshots/00085/00085276.png)

### Mel O Dee by Resistance (2nd place at Xenium 2021, Wild compo)
https://www.pouet.net/prod.php?which=89698

![Mel O Dee](https://content.pouet.net/files/screenshots/00089/00089698.jpg)


