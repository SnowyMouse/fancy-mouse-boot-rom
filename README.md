# Fancy Mouse Boot ROM

This boot rom can boot an Xbox BIOS. It contains absolutely no code copyrighted
by Microsoft, so you are free to distribute it. See LICENSE.txt for more
information.

## What does it do?

This boot ROM accomplishes the following:

- Sets up the GDT
- Enables protected mode
- Enables 32-bit mode (since x86 starts in a backwards-compatible 16-bit mode)
- Loads and interprets opcodes to initialize the console
- Decodes, verifies, and passes off to the Xbox's second-stage bootloader
  (<4817 kernels)
- Verifies and passes off to the BIOS (4817 or newer kernels)

And it manages to support all (original) BIOSes despite the 512 byte limitation!

## Which kernels are the boot ROM compatible with?

The mouse.bin file should be able to boot all **original** Xbox BIOSes, but
4817 or newer kernels (AKA "1.1+" kernels) are not very well tested due to a
lack of current support in Xemu for debugging.

If built from source, mouse_rev0.bin boots older BIOSes, and mouse_rev1.bin
boots newer BIOSes.

Please note that modified BIOSes or BIOSes built with hacked or leaked source
code are not supported. If any issues are experienced with such a BIOS, **you
are on your own**. The verification processes done on this boot ROM are intended
intended to match the verification processes done on the original boot ROMs for
the sake of accuracy.

## How do I compile this?

These are the requirements:

- GCC 8 or newer that can compile or cross-compile for 32-bit x86 CPUs
- GNU Make (used for making it)
- `fallocate` and `dd` (comes with most GNU/Linux distros)
- Optional: Git - Makes it easy to quickly clone and build from a terminal

To compile:

1. Clone the repo and change directory
```
$ git clone https://github.com/SnowyMouse/fancy-mouse-boot-rom && cd fancy-mouse-boot-rom
```

2. If you are not on an x86-based PC, you may want to edit the makefile to make
   it use the correct GCC implementation.

3. Run make
```
$ make
```

The resulting file will be called mouse.bin in the bin folder.

## Can I use this legally?

We aren't an expert on law. However, there are a few things to note:

- None of the code in here is copyrighted by Microsoft. The opcode interpreter
  is written entirely from scratch. The ARCFOUR and TEA algorithms are not owned
  by Microsoft, thus they cannot copyright them.

- We have not agreed to any contractual agreement that states we cannot do this,
  and you probably have not agreed to any contractual agreement that states you
  cannot use this.

## Credits

- SnowyMouse: I wrote it!

- Vaporeon: Testing, missing information~

- Matt Borgerson: His "[Deconstructing the Xbox Boot ROM]" was used in the
  creation of this project. This actually made this project possible, since
  extracting a real MCPX boot rom and then reverse engineering it was out of the
  scope and capabilities of what I can actually do.

- The [Xemu] project: This was extremely helpful so I can debug this with GDB.

- The [Xbox Dev Wiki]: This was helpful for knowing what the rev1 MCPX does.

[Deconstructing the Xbox Boot ROM]: https://mborgerson.com/deconstructing-the-xbox-boot-rom/
[Xemu]: https://xemu.app/
[Xbox Dev Wiki]: https://xboxdevwiki.net/MCPX_ROM
