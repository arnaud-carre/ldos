@set path=%path%;../bin/vasm/
vc -O2 -notmpfile -nostdlib -o "../bin/hdd_loader.exe" hdd_loader.asm
vasmm68k_mot_win32 -Fbin -o "../bin/boot.bin" boot.asm
vasmm68k_mot_win32 -Fbin -o "../bin/boot2.bin" boot2.asm
vasmm68k_mot_win32 -Fbin -o "../bin/kernel.bin" kernel.asm
pause
