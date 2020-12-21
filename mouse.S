# Fancy Mouse Boot ROM
# Copyright (C) 2020 SnowyMouse
#
# Permission is hereby granted under the terms of version 2 of the GNU GPL to
# use, modify, and.or redistribute this program, or, at your option, version 3
# of the GNU GPL.
#
# See LICENSE.txt for more information.

# Note we're using Intel syntax
.intel_syntax noprefix

# Main code (0xFFFFFE00)
.text

text_start:

# Operand 1 register
#define OP1_REG edi

# Operand 2 register
#define OP2_REG esi

# Result register
#define RES_REG ebp

# Opcode register
#define OPC_REG8 al
#define OPC_REG32 eax

# Scratch register
#define SCR_REG ecx

# Command pointer
#define CMD_REG esp

# Temporary value register
#define TMP_REG32 edx
#define TMP_REG16 dx
#define TMP_REG8 dl

# Jump address register
#define JMP_REG32 ebx
#define JMP_REG8 bl

# Result = *(OP1 & 0x0FFFFFFF)
# I could forego doing the binary AND and save a few bytes, but it wouldn't functionally be the same
read_memory:
    and OP1_REG, 0x0FFFFFFF # Basically limits ROM to reading first 16 MiB of VM
    mov RES_REG, dword ptr [OP1_REG]
    jmp read_next_command

# *OP1 = OP2
write_memory:
    mov dword ptr [OP1_REG], OP2_REG
    jmp read_next_command

# Write to PCI space
write_pci:
    cmp OP1_REG, 0x80000880
    jne continue_write_pci
    and OP2_REG, 0xFFFFFFFD
    continue_write_pci:

    # Have to use the opcode register for this one since out only works with eax, and we don't have a stack
    mov OPC_REG32, OP1_REG
    out TMP_REG16, OPC_REG32

    add TMP_REG8, 4 # effectively set it to 0xCFC
    mov OPC_REG32, OP2_REG
    out TMP_REG16, OPC_REG32

    jmp read_next_command

# Read from PCI space
read_pci:
    mov OPC_REG32, OP1_REG
    out TMP_REG16, OPC_REG32

    add TMP_REG8, 4
    in OPC_REG32, TMP_REG16
    mov RES_REG, OPC_REG32

    jmp read_next_command

# Binary AND result with OP1 and OR with OP2
and_then_or:
    and RES_REG, OP1_REG
    or RES_REG, OP2_REG
    jmp read_next_command

# Same as "and then or" but with the scratch register)
and_then_or_scratch_reg:
    and SCR_REG, OP1_REG
    or SCR_REG, OP2_REG
    mov RES_REG, SCR_REG
    jmp read_next_command

# Shift the registers and then interpret the opcode
# op1 --> opcode
# op2 --> op1
# res --> op2
chain_command:
    mov OPC_REG32, OP1_REG
    mov OP1_REG, OP2_REG
    mov OP2_REG, RES_REG
    jmp begin_execute_command

# Read from I/O port
write_io:
    mov TMP_REG32, OP1_REG
    mov OPC_REG32, OP2_REG
    out TMP_REG16, OPC_REG8
    jmp read_next_command

# Write to I/O port
read_io:
    mov TMP_REG32, OP1_REG
    in OPC_REG8, TMP_REG16
    movsx RES_REG, OPC_REG8
    jmp read_next_command

# Let's begin.
.code16
main16:
    # First set up the GDT
    lgdtd cs:gdt_reference

    # There is code to set up the IDT, too, but it's not a valid IDT, so... uh... we don't need to do it
    # lidtd cs:gdt_reference

    # Enable protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax
    
    # Jump into main32
    # jmp dword 0x0008:main32 - I have to write this out
    .byte 0x66, 0xEA
    .long main32
    .short 0x0008
.code32

# Do a jump if operand 1 != result (effectively a no-op on startup since OP2_REG - esi - is 0, so it saves us from writing an extra jmp)
branch_jne:
    cmp RES_REG, OP1_REG
    je read_next_command
    
# Add operand 2 to the command pointer
jump_offset:
    add CMD_REG, OP2_REG

# Load the opcode
read_next_command:
    # Read the opcode
    mov OPC_REG8, byte ptr [CMD_REG]
    inc CMD_REG
    
    # First/second operand
    pop OP1_REG
    pop OP2_REG
    
    # Hold this here
    mov TMP_REG16, 0xCF8
    
    # Are we done?
    cmp OPC_REG8, 0xEE
    je finish_commands

begin_execute_command:
    # Greater than 18? Go to read_next_command
    cmp OPC_REG8, 18
    ja read_next_command

    # 0-9? Go to the thing
    cmp OPC_REG8, 9
    jbe execute_command

    # 16-18? Go to the thing
    cmp OPC_REG8, 16
    jae execute_command_16_to_18

    # 10-15? Go to read_next_command
    jmp read_next_command

execute_command_16_to_18:
    # Subtract 6, since the first opcode is 16 and we want the 16th opcode to be the 10th index
    sub OPC_REG8, 6

execute_command:
    # Get the function pointer as an offset from 0xFFFFFE00.
    movsx OPC_REG32, OPC_REG8
    mov JMP_REG32, OFFSET text_start
    mov JMP_REG8, byte ptr [opcodes_functions + OPC_REG32]

    # Call it
    jmp JMP_REG32

finish_commands:
    # Initialize MTRRs (0x200-0x20F)
    xor eax, eax
    xor ecx, ecx
    xor edx, edx
    mov ch, 2

clear_mtr_loop:
    wrmsr
    inc ecx
    cmp cl, 0xF
    jna clear_mtr_loop
    mov cl, 0xFF
    mov eax, OP1_REG
    wrmsr

enable_caching:
    # Enable caching
    mov eax, cr0
    and eax, 0x9FFFFFFF
    mov cr0, eax

    # Before we verify, set this
    #ifdef BIOS1
    mov esp, 0x8F014
    #else
    mov esp, 0x8F000
    #endif

#ifdef BIOS1
# This actually runs encrypt() for TEA to verify that the second stage bootloader is correct. This is NOT required to load anything - it is merely a verification.
# See https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm for information on the TEA algorithm (and why it's a BAD idea for hashing here)

#define TEA_START 0xFFFFD400
#define TEA_END 0xFFFFFC80

tea_verify_begin:
    # ebp = offset
    # ecx = i
    # esi = h0
    # edi = h1
    
    # [esp+0]  = TEA_END, h0
    # [esp+4]  = 0, h1
    # [esp+8]  = h2
    # [esp+12] = h3
    # [esp+16] = k0
    # [esp+20] = k1
    # [esp+24] = k2
    # [esp+28] = k3
    # [esp+32] = tmph1
    # [esp+36] = tmph2
    
    mov esi, TEA_START # h0 = TEA_START
    mov edi, TEA_END # h1 = TEA_END
    
    xor ecx, ecx
    push esi # h3 = TEA_START (the original boot ROM did 0x8F000 - the stack pointer - so we'll get a different hash, but it isn't any less... or more secure. and it saves three bytes of space~)
    push edi # h2 = TEA_END
    push ecx # 0 (used later)
    push edi # TEA_END
    
    # offset = TEA_START
    mov ebp, esi

# Initialize more values here
tea_outer_loop:
    # sum = 0
    xor edx, edx
    
    add esp, 32
    push dword ptr [ebp + 4] # k3 = *(offset + 4)
    push dword ptr [ebp] # k2 = *offset
    push edi # k1 = h1
    push esi # k0 = h0

# Run TEA encrypt() as a hash... what could possibly go wrong? (loop 32 times)
tea_inner_loop:
    # sum += delta (golden ratio)
    add edx, 0x9E3779B9
    
half_tea:
    # eax = (h1 + sum)
    mov eax, edi
    add eax, edx
    
    # ebx = ((h1 << 4) + k0)
    mov ebx, edi
    shl ebx, 4
    add ebx, dword ptr [esp]
    
    # eax = (h1 + sum) ^ ((h1 << 4) + k0)
    xor eax, ebx
    
    pop ebx # add 4 to esp
    
    # ebx = ((h1 >> 5) + k1)
    mov ebx, edi
    shr ebx, 5
    add ebx, dword ptr [esp]
    
    # eax = eax ^ ebx
    xor eax, ebx
    add esi, eax
    
    # Have h0/h1 swap places
    xchg edi, esi
    
    # Are we done?
    xor ch, 1
    jz half_tea_done
    
    # Guess not. Let's continue.
    pop eax # add esp, 4
    jmp half_tea
    
half_tea_done:
    sub esp, 12
    
    cmp dl, 0x20
    jne tea_inner_loop # do that 32 times (edx % 0xFF = 0x20 after 32 times; funny coincidence)

# Keep going...?
tea_outer_loop_continued:
    # Go back
    sub esp, 16
    
    # h2 <-> h0
    xchg dword ptr [esp+8], esi
    
    # h3 <-> h1
    xchg dword ptr [esp+12], edi
    
    # offset += increment
    add ebp, ecx
    
    # increment ^= 8 - effectively add 8 only every other run to hash all 16 bytes
    xor ecx, 0x8
    
    # check if ebp < TEA_END is still true
    cmp ebp, dword ptr [esp]
    
    jb tea_outer_loop

# Compare against the hash. If it matches, load into the second stage bootloader
tea_verify:
    # Finish (set h0/h1 in esp)
    pop eax # add esp, 8, but with two bytes
    pop eax # this sets eax to 0 since we had the value at [esp+4] set to 0 earlier
    push edi
    push esi
    
    # Check hashes
    mov cl, 4
    mov esi, esp
    mov edi, OFFSET tea_hash
    rep cmpsd dword ptr [esi], dword ptr [edi]
    
    # Done~
    je TEA_START
    
    # Fallthrough to error handler
#endif

#ifdef BIOS0

decode_arc4:
    # ARCFOUR KSA - Initialize everything to FF -> FE -> FD, etc.
    #ifdef BIOS1
    push eax # set the first byte to 0 (mangled by the TEA thing)
    mov cl, 0xFF # we only need to do this if we just went through the TEA thing, as ecx would otherwise still be set to 0xFF from clear_mtr_loop
    #endif
arcfour_key_schedule_loop:
    mov byte ptr [esp + ecx], cl
    loop arcfour_key_schedule_loop

arcfour_key_loop_begin:
    # Load our key
    xor edi, edi
    xor ebx, ebx

arcfour_key_loop:
    mov dl, byte ptr [esp + ecx]
    add bl, byte ptr [arc4_key_0 + edi]
    add bl, dl
    mov al, byte ptr [esp + ebx]
    mov byte ptr [esp + ecx], al
    mov byte ptr [esp + ebx], dl
    inc edi
    and edi, 0xF # prevent ecx from going above 0x10
    inc cl
    jnz arcfour_key_loop # if cl rolls over to 0, jump!
    
arcfour_key_loop_done:
    xor edx, edx

    # Addresses to hold our input/output for when we do encryption
    #define ARCFOUR_ENCRYPTED_DATA_ADDR 0xFFFF9E00
    #define ARCFOUR_ENCRYPTED_DATA_SIZE (0xFFFFFE00 - 0xFFFF9E00)
    #define ARCFOUR_DECRYPTED_DATA_ADDR 0x00090000

    mov esi, ARCFOUR_DECRYPTED_DATA_ADDR
    
arcfour_encode_loop:
    # Now actually decode the bootloader
    # Encrypted is stored at 0xFFFF9E00
    # Decrypted is stored at 0x00090000 - this is where we're going to jump to
    
    inc cl
    mov al, byte ptr [esp + ecx]
    add dl, al
    mov bl, byte ptr [esp + edx]
    mov byte ptr [esp + ecx], bl
    mov byte ptr [esp + edx], al
    add al, bl
    mov bl, byte ptr [ARCFOUR_ENCRYPTED_DATA_ADDR + edi]
    xor bl, byte ptr [esp + eax]
    mov byte ptr [esi + edi], bl
    inc edi
    cmp di, ARCFOUR_ENCRYPTED_DATA_SIZE
    jb arcfour_encode_loop

arcfour_sanity_check:
    # Do a sanity check
    cmp dword ptr [0x95FE4], 0x7854794A
    jne error_handler
    jmp dword ptr [esi]
#endif

# We died!
error_handler:
    int3

# This is the hash we expect (verifies it's correct)
tea_hash:
    .long 0xAF6740C7, 0xDAD52A5D, 0xC133D584, 0x7A56385C

# Keys, GDT, hashes, etc.
.section .more_data

#ifdef BIOS1
arc4_key_1:
    .byte 0xB4, 0x71, 0xEF, 0x97, 0x06, 0x5F, 0x49, 0x0A, 0xE0, 0xF7, 0x2A, 0xA2, 0xC7, 0x40, 0x67, 0xAF
#endif
#ifdef BIOS0
arc4_key_0:
    .byte 0x27, 0x45, 0xA9, 0x10, 0x39, 0x7E, 0x6A, 0xA6, 0x86, 0xFB, 0x4B, 0x1A, 0x4B, 0xA9, 0x0F, 0xD2
#endif
    
# Global descriptor table
gdt_table:
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x9B, 0xCF, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x93, 0xCF, 0x00

# Now we're in 32-bit mode
main32:
    # Set es, ds, and ss each to 0x10
    xor eax, eax
    mov al, 0x10
    mov ds, eax
    mov ss, eax
    mov es, eax

    # Run commands from ROM
    mov CMD_REG, 0xFF000080
    
    # Begin
    jmp read_next_command

# Global descriptor reference
gdt_reference:
    # Limit
    .short 0x0018

    # Base
    .long gdt_table

# Reset vector (0xFFFFFFF0)
# This is where execution starts. We have exactly 16 bytes to work with this section.
.section .reset_vector

# This is our entry point.
.code16
entry_point:
    jmp main16
.code32
    
# Store the opcode's respective functions as 8-bit offsets from text_start, which is 0xFFFFFE00
opcodes_functions:
    # 0-1
    .byte (read_next_command - text_start)
    .byte (read_next_command - text_start)
    
    # 2-9
    .byte (read_memory - text_start)
    .byte (write_memory - text_start)
    .byte (write_pci - text_start)
    .byte (read_pci - text_start)
    .byte (and_then_or - text_start)
    .byte (chain_command - text_start)
    .byte (branch_jne - text_start)
    .byte (jump_offset - text_start)
    # 16-18
    .byte (and_then_or_scratch_reg - text_start)
    .byte (write_io - text_start)
    .byte (read_io - text_start)
