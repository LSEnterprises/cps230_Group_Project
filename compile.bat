@set path=C:\Users\Owner\AppData\Local\NASM;%path%
nasm -fbin -okernel.img kernel.asm
nasm -fbin -oboot.img boot.asm
call mkfloppy.exe bootdisk.img boot.img kernel.img 