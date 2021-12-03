cd greetings
call m.cmd < nul
cd ../sprites_loader
call m.cmd < nul
cd ..
rem you could use LSPConvert -amigapreview command to generate a .wav file of your music
..\ldos\bin\LSPConvert parcade.mod -noinsane
..\ldos\bin\ldos.exe script.txt ldos_demo.adf
pause
explorer a500.uae
