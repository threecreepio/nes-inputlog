AS = ca65
CC = cc65
LD = ld65

.PHONY: clean

build: inputlog.nes

%.o: %.asm
	$(AS) -g --create-dep "$@.dep" --debug-info $< -o $@

inputlog.nes: layout main.o
	$(LD) --dbgfile $@.dbg -C $^ -o $@

clean:
	rm -f inputlog.nes *.dep *.o *.dbg

include $(wildcard *.dep)
