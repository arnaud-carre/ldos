cd greetings
call m.cmd < nul
cd ../sprites_loader
call m.cmd < nul
cd ..
rem you could use LSPConvert -amigapreview command to generate a .wav file of your music
..\ldos\bin\LSPConvert parcade.mod -getpos
..\ldos\bin\LSPConvert ignition.mod -getpos
..\ldos\bin\LSPConvert ignition_large.mod -getpos
..\ldos\bin\LSPConvert orbit.mod -getpos
..\ldos\bin\LSPConvert orbit_small.mod -getpos
..\ldos\bin\ldos.exe script.txt ldos_demo.adf
