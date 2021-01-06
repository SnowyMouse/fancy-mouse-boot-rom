DD=dd
CC=gcc
OBJCOPY=objcopy
FALLOCATE=fallocate
CFLAGS=-m32 -Wl,--section-start=.text=0xFFFFFE00,--section-start=.reset_vector=0xFFFFFFF0,-e0xFFFFFFF0,--section-start=.more_data=0xFFFFFF9C,-e0xFFFFFF9C,-g -g -no-pie -nostdlib

all: bin/mouse_rev0.bin bin/mouse_rev1.bin

bin/mouse_rev0.bin: bin/intermediate/intermediate
	$(CC) $(CFLAGS) -DBIOS0 -o bin/intermediate/mouse_rev0.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/intermediate/text_rev0 bin/intermediate/mouse_rev0.o /dev/null
	$(OBJCOPY) -O binary --dump-section .more_data=bin/intermediate/more_data_rev0 bin/intermediate/mouse_rev0.o /dev/null
	$(OBJCOPY) -O binary --dump-section .reset_vector=bin/intermediate/reset_vector_rev0 bin/intermediate/mouse_rev0.o /dev/null
	$(FALLOCATE) bin/mouse_rev0.bin --length 512
	$(DD) if=bin/intermediate/text_rev0 of=bin/mouse_rev0.bin conv=notrunc status=none
	$(DD) if=bin/intermediate/more_data_rev0 of=bin/mouse_rev0.bin oflag=seek_bytes seek=412 conv=notrunc status=none
	$(DD) if=bin/intermediate/reset_vector_rev0 of=bin/mouse_rev0.bin oflag=seek_bytes seek=496 conv=notrunc status=none

bin/mouse_rev1.bin: bin/intermediate/intermediate
	$(CC) $(CFLAGS) -DBIOS1 -o bin/intermediate/mouse_rev1.o mouse.S
	$(OBJCOPY) -O binary --dump-section .text=bin/intermediate/text_rev1 bin/intermediate/mouse_rev1.o /dev/null
	$(OBJCOPY) -O binary --dump-section .more_data=bin/intermediate/more_data_rev1 bin/intermediate/mouse_rev1.o /dev/null
	$(OBJCOPY) -O binary --dump-section .reset_vector=bin/intermediate/reset_vector_rev1 bin/intermediate/mouse_rev1.o /dev/null
	$(FALLOCATE) bin/mouse_rev1.bin --length 512
	$(DD) if=bin/intermediate/text_rev1 of=bin/mouse_rev1.bin conv=notrunc status=none
	$(DD) if=bin/intermediate/more_data_rev1 of=bin/mouse_rev1.bin oflag=seek_bytes seek=412 conv=notrunc status=none
	$(DD) if=bin/intermediate/reset_vector_rev1 of=bin/mouse_rev1.bin oflag=seek_bytes seek=496 conv=notrunc status=none
	
bin/intermediate/intermediate:
	mkdir -p bin/intermediate
	touch bin/intermediate/intermediate

clean:
	rm -rf bin
