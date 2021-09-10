@set path=%path%;../bin/vasm/
vc -O2 -notmpfile -nostdlib -o "../bin/hdd_loader.exe" hdd_loader.asm
vasmm68k_mot_win32 -Fbin -o p61player.bin p61player.asm
"../bin/as68" boot.asm -o "../bin/boot.bin"
"../bin/as68" boot2.asm -o "../bin/boot2.bin"
"../bin/as68" kernel.asm -o "../bin/kernel.bin"
copy kernel.inc ..
pause
