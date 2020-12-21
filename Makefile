DD=dd
CC=gcc
OBJCOPY=objcopy
FALLOCATE=fallocate
CFLAGS=-m32 -Wl,--section-start=.text=0xFFFFFE00,--section-start=.reset_vector=0xFFFFFFF0,-e0xFFFFFFF0,--section-start=.more_data=0xFFFFFF9C,-e0xFFFFFF9C,-g -g -no-pie -nostdlib

all: bin/mouse_rev0.bin bin/mouse_rev1.bin

bin/mouse_rev0.bin: bin/intermediate/reset_vector
	$(CC) $(CFLAGS) -DBIOS0 -o bin/intermediate/mouse_rev0.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/intermediate/text_rev0 bin/intermediate/mouse_rev0.o /dev/null
	$(OBJCOPY) -O binary --dump-section .more_data=bin/intermediate/more_data_rev0 bin/intermediate/mouse_rev0.o /dev/null
	$(FALLOCATE) bin/mouse_rev0.bin --length 512
	$(DD) if=bin/intermediate/text_rev0 of=bin/mouse_rev0.bin conv=notrunc status=none
	$(DD) if=bin/intermediate/more_data_rev0 of=bin/mouse_rev0.bin oflag=seek_bytes seek=412 conv=notrunc status=none
	$(DD) if=bin/intermediate/reset_vector of=bin/mouse_rev0.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/mouse_rev1.bin: bin/intermediate/reset_vector
	$(CC) $(CFLAGS) -DBIOS1 -o bin/intermediate/mouse_rev1.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/intermediate/text_rev1 bin/intermediate/mouse_rev1.o /dev/null
	$(OBJCOPY) -O binary --dump-section .more_data=bin/intermediate/more_data_rev1 bin/intermediate/mouse_rev1.o /dev/null
	$(FALLOCATE) bin/mouse_rev1.bin --length 512
	$(DD) if=bin/intermediate/text_rev1 of=bin/mouse_rev1.bin conv=notrunc status=none
	$(DD) if=bin/intermediate/more_data_rev1 of=bin/mouse_rev1.bin oflag=seek_bytes seek=412 conv=notrunc status=none
	$(DD) if=bin/intermediate/reset_vector of=bin/mouse_rev1.bin oflag=seek_bytes seek=496 conv=notrunc status=none

# this does not work since we need a certain number of bytes freed, and I don't think that's possible
bin/mouse.bin: bin/intermediate/reset_vector
	$(CC) $(CFLAGS) -DBIOS1 -DBIOS0 -o bin/intermediate/mouse.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/intermediate/text bin/intermediate/mouse.o /dev/null
	$(OBJCOPY) -O binary --dump-section .more_data=bin/intermediate/more_data bin/intermediate/mouse.o /dev/null
	$(FALLOCATE) bin/intermediate/mouse.bin --length 512
	$(DD) if=bin/intermediate/text of=bin/mouse.bin conv=notrunc status=none
	$(DD) if=bin/intermediate/more_data of=bin/mouse.bin oflag=seek_bytes seek=412 conv=notrunc status=none
	$(DD) if=bin/intermediate/intermediate/reset_vector of=bin/mouse.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/intermediate/reset_vector:
	mkdir -p bin/intermediate
	$(CC) $(CFLAGS) -o bin/intermediate/mouse.o mouse.S
	$(OBJCOPY) -O binary --dump-section .reset_vector=bin/intermediate/reset_vector bin/intermediate/mouse.o /dev/null

clean:
	rm -rf bin
