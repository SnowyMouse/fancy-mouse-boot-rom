# Fancy Mouse Boot ROM

This boot rom can boot an Xbox BIOS. It contains absolutely no code copyrighted
by Microsoft, so you are free to distribute it under the terms of the GPL. See
LICENSE.txt for more information.

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

mouse_rev0.bin boots older BIOSes (<4817 kernels), and mouse_rev1.bin boots only
newer BIOSes (4817+ kernels).

This boot ROM also support the free [Cromwell] BIOS.

[Cromwell]: https://github.com/XboxDev/cromwell

### Regarding hacked BIOSes (e.g. Complex, Xecutor, etc.)

The verification processes on this boot ROM are intended to match verification
done on **original** consoles for the sake of accuracy. As such, BIOSes built
with leaked source code are not directly supported.

If you encounter issues with these BIOSes, check to make sure the issues occur
on an original BIOS dumped from a retail Xbox.

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

## Special thanks

- [Vaporeon] : Testing, missing information
- [Skryptonyte] : [Fixes](https://github.com/SnowyMouse/fancy-mouse-boot-rom/pull/3/commits/1996e66c4e73d279818173fac244d578f1e9b679)
- [Matt Borgerson] : His "[Deconstructing the Xbox Boot ROM (Archived)]" was used
  in the creation of this project. This actually made this project possible,
  since extracting a real MCPX boot rom and then reverse engineering it was out
  of the scope and capabilities of what I can actually do.
- The [Xemu] project : This was extremely helpful so I can debug this with GDB.
- The [Xbox Dev Wiki] : This was helpful for knowing what the rev1 MCPX does.

[Vaporeon]: https://github.com/Vaporeon
[Skryptonyte]: https://github.com/Skryptonyte
[Matt Borgerson]: https://github.com/mborgerson
[Deconstructing the Xbox Boot ROM (Archived)]: https://web.archive.org/web/20201108132438/https://mborgerson.com/deconstructing-the-xbox-boot-rom/
[Xemu]: https://xemu.app/
[Xbox Dev Wiki]: https://xboxdevwiki.net/MCPX_ROM
