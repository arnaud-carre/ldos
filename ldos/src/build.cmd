@set path=%path%;../bin/vasm/
vc -O2 -notmpfile -nostdlib -o "../bin/hdd_loader.exe" hdd_loader.asm
rem vasmm68k_mot_win32 -Fbin -o p61player.bin p61player.asm
vasmm68k_mot_win32 -Fbin -o "../bin/boot.bin" boot.asm
vasmm68k_mot_win32 -Fbin -o "../bin/boot2.bin" boot2.asm
vasmm68k_mot_win32 -Fbin -o "../bin/kernel.bin" kernel.asm
copy kernel.inc ..
pause
