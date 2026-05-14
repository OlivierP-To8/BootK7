all: BootMO.k7 BootTO.k7

clean:
	rm *.lst *.html *.BIN *.k7
	make -C tools clean

k7mofs: tools/k7mofs
	make -C tools k7mofs

k7tofs: tools/k7tofs
	make -C tools k7tofs

tools/c6809:
	make -C tools/c6809-v1.0
	cp tools/c6809-v1.0/c6809 tools/c6809

BootK7MO.BIN: tools/c6809 BootK7MO.asm
	tools/c6809 -bl BootK7MO.asm

IntroMO.BIN: tools/c6809 IntroMO.asm
	tools/c6809 -bl IntroMO.asm

DemoMO.BIN: tools/c6809 DemoMO.asm
	tools/c6809 -bl DemoMO.asm

Fire.BIN: tools/c6809 Fire.asm
	tools/c6809 -bl Fire.asm

BootMO.k7: tools/k7mofs BootK7MO.BIN IntroMO.BIN DemoMO.BIN Fire.BIN
	tools/k7mofs -add $@ BootK7MO.BIN IntroMO.BIN DemoMO.BIN Fire.BIN

BootK7TO.BIN: tools/c6809 BootK7TO.asm
	tools/c6809 -bl BootK7TO.asm

IntroTO.BIN: tools/c6809 IntroTO.asm
	tools/c6809 -bl IntroTO.asm

DemoTO.BIN: tools/c6809 DemoTO.asm
	tools/c6809 -bl DemoTO.asm

BootTO.k7: tools/k7tofs BootK7TO.BIN IntroTO.BIN DemoTO.BIN Fire.BIN
	tools/k7tofs -add $@ BootK7TO.BIN IntroTO.BIN DemoTO.BIN Fire.BIN
