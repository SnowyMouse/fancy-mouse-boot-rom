DD=dd
CC=gcc
OBJCOPY=objcopy
FALLOCATE=fallocate
CFLAGS=-m32 -Wl,--section-start=.text=0xFFFFFE00,--section-start=.reset_vector=0xFFFFFFF0,-e0xFFFFFFF0,-g -g -no-pie -nostdlib

bin/mouse.bin: bin/reset_vector bin/text
	$(FALLOCATE) bin/mouse.bin --length 512
	$(DD) if=bin/text of=bin/mouse.bin conv=notrunc status=none
	$(DD) if=bin/reset_vector of=bin/mouse.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/mouse.o:
	mkdir -p bin
	$(CC) $(CFLAGS) -o bin/mouse.o mouse.S

bin/reset_vector bin/text: bin/mouse.o
	$(OBJCOPY) -O binary --dump-section .reset_vector=bin/reset_vector --dump-section .text=bin/text bin/mouse.o /dev/null

clean:
	rm -rf bin
