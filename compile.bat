@set path=C:\Users\abpri\AppData\Local\NASM;%path%
nasm -fbin -okernel.img kernel.asm
nasm -fbin -oboot.img boot.asm
call mkfloppy.exe bootdisk.img boot.img kernel.img 
call c:\cps230\bin\dbd.exe .