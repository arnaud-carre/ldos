# <div align="center">LDOS (Leonard Demo Operating System)</div>

## Introduction
LDOS is a framework to easily build Amiga multi-part demos. You can chain several amiga executable effects. LDOS is managing memory allocation, floppy disk loading, data depacking and image disk creation. LDOS also includes an HDD loader to run your demo from harddisk. LDOS toolchain is running on Windows platform.

## Demo sample
LDOS repository also comes with a demo sample so you can see how to use LDOS in real life application. Just run demo/build.cmd to build the sample LDOS demo. It will produce "ldos_demo.adf" file. You can use it in any Amiga emulator or write on real floppy and test on real hardware.
The sample demo is made of 3 files (look at demo/script.txt)
1. parcade.p61 ( p61 music file )
2. Sprite loader: few animated sprites during the loading & depacking of the second part
3. Greetings: large bitmap scroll

## Building LDOS
LDOS comes with pre-assembled binaries. ( ldos/bin ). But if you want to modify & build yourself, just run ldos/src/build.cmd

## LDOS Technical details
* LDOS should run on any Amiga ( from A500 to 060 )
* LDOS is primary made for A500 demo. If ran on higger amiga, CPU caches are switched off
* Generated demo is 1MiB RAM targeted ( with at least 512KiB of chip memory )
* Use ARJ mode 7 packer
* LDOS is loading & depacking at the same time. Most of demos are loading, then depacking. LDOS depacks while loading, so basically depacking time is free.
* Just put all the exe of your demo in a script.txt and run ldos/bin/install ( look at demo/build.cmd script )
* fun fact: All data on the disk is packed except the bootsector. As boot code is pretty small, the rest of 1024 bytes bootblock is also used to store disk data

## Credits

* LDOS is written by Arnaud Carré (aka Leonard/Oxygene)
* ARJ depackers by Mr Ni! / TOS-crew
* P61 music player by Photon/Scoopex

## Amiga demos using LDOS
LDOS is production ready :) Several Amiga demos are already powered by LDOS:

### The Fall by The Deadliners & Lemon.
https://www.pouet.net/prod.php?which=75773

![The Fall](https://content.pouet.net/files/screenshots/00075/00075773.png)

### De Profundis by The Deadliners & Lemon. & Oxygene
https://www.pouet.net/prod.php?which=81081

![De Profundis](https://content.pouet.net/files/screenshots/00081/00081081.jpg)

### AmigAtari by Oxygene
https://www.pouet.net/prod.php?which=85276

![AmigAtari](https://content.pouet.net/files/screenshots/00085/00085276.png)

### Mel O Dee by Resistance
https://www.pouet.net/prod.php?which=89698

![Mel O Dee](https://content.pouet.net/files/screenshots/00089/00089698.jpg)


