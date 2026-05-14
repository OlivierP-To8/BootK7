tools\c6809.exe -bl BootK7MO.asm
tools\c6809.exe -bl IntroMO.asm
tools\c6809.exe -bl DemoMO.asm
tools\c6809.exe -bl Fire.asm
tools\k7mofs.exe -add BootMO.k7 BootK7MO.BIN IntroMO.BIN DemoMO.BIN Fire.BIN

tools\c6809.exe -bl BootK7TO.asm
tools\c6809.exe -bl IntroTO.asm
tools\c6809.exe -bl DemoTO.asm
tools\k7tofs.exe -add BootTO.k7 BootK7TO.BIN IntroTO.BIN DemoTO.BIN Fire.BIN
