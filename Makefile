DD=dd
CC=gcc
OBJCOPY=objcopy
FALLOCATE=fallocate
CFLAGS=-m32 -Wl,--section-start=.text=0xFFFFFE00,--section-start=.reset_vector=0xFFFFFFF0,-e0xFFFFFFF0,-g -g -no-pie -nostdlib

all: bin/mouse_rev0.bin bin/mouse_rev1.bin bin/mouse.bin

bin/mouse_rev0.bin: bin/reset_vector
	$(CC) $(CFLAGS) -DBIOS0 -o bin/mouse_rev0.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/text_rev0 bin/mouse_rev0.o /dev/null
	$(FALLOCATE) bin/mouse_rev0.bin --length 512
	$(DD) if=bin/text_rev0 of=bin/mouse_rev0.bin conv=notrunc status=none
	$(DD) if=bin/reset_vector of=bin/mouse_rev0.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/mouse_rev1.bin: bin/reset_vector
	$(CC) $(CFLAGS) -DBIOS1 -o bin/mouse_rev1.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/text_rev1 bin/mouse_rev1.o /dev/null
	$(FALLOCATE) bin/mouse_rev1.bin --length 512
	$(DD) if=bin/text_rev1 of=bin/mouse_rev1.bin conv=notrunc status=none
	$(DD) if=bin/reset_vector of=bin/mouse_rev1.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/mouse.bin: bin/reset_vector
	$(CC) $(CFLAGS) -DBIOS1 -DBIOS0 -o bin/mouse.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/text bin/mouse.o /dev/null
	$(FALLOCATE) bin/mouse.bin --length 512
	$(DD) if=bin/text of=bin/mouse.bin conv=notrunc status=none
	$(DD) if=bin/reset_vector of=bin/mouse.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/reset_vector:
	mkdir -p bin
	$(CC) $(CFLAGS) -o bin/mouse.o mouse.S
	$(OBJCOPY) -O binary --dump-section .reset_vector=bin/reset_vector bin/mouse.o /dev/null

clean:
	rm -rf bin
