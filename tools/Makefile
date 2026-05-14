all: k7mofs k7tofs c6809

clean:
	make -C c6809-v1.0 clean
	-rm k7mofs k7tofs c6809

k7mofs: k7mofs.c
	gcc -o $@ $@.c

k7mofs.exe: k7mofs.c
	i686-w64-mingw32-gcc -o $@ k7mofs.c

k7tofs: k7tofs.c
	gcc -o $@ $@.c

k7tofs.exe: k7tofs.c
	i686-w64-mingw32-gcc -o $@ k7tofs.c

c6809:
	make -C c6809-v1.0 all
	cp c6809-v1.0/c6809 .

