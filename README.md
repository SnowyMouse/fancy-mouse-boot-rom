# Fancy Mouse Boot ROM

This boot rom can load an Xbox BIOS. It contains absolutely no code copyrighted
by Microsoft, so you are free to distribute it. See LICENSE.txt for more
information.

## What does it do?

This boot ROM accomplishes the following:

- Sets up the GDT
- Enables protected mode
- Enables 32-bit mode (since x86 starts in a backwards-compatible 16-bit mode)
- Loads and interprets opcodes to initialize the console
- Decodes and passes off to the Xbox's second-stage bootloader (<4817 kernels)
- Verifies and passes off to the BIOS (4817 or newer kernels)

It does so with plenty of bytes to spare despite the 512 byte limitation!

## Which file do I use?

The version you use depends on the BIOS kernel:

- If you are using a kernel revision prior to 4817, use mouse_rev0.bin
- If you are using kernel revision 4817 or later, use mouse_rev1.bin

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

- Vaporeon: Testing, missing information.

- Matt Borgerson: [Deconstructing the Xbox Boot ROM] was used in the creation of
  this project. This actually made this project possible, since extracting a
  real MCPX boot rom and then reverse engineering it was out of the scope of
  what I can actually do.

- The [Xemu] project: Extremely helpful so I can debug this with GDB.

- The [Xbox Dev Wiki]: Helpful for knowing what the rev1 MCPX does.

[Deconstructing the Xbox Boot ROM]: https://mborgerson.com/deconstructing-the-xbox-boot-rom/
[Xemu]: https://xemu.app/
