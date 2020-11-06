# Fancy Mouse Boot ROM
# Copyright (C) 2020 SnowyMouse

# Note we're using Intel syntax
.intel_syntax noprefix

# Main code (0xFFFFFE00)
.text

text_start:

#define TEXT_START_ADDR 0xFFFFFE00

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
#define CMD_REG ebx

# Temporary value register
#define TMP_REG32 edx
#define TMP_REG16 dx
#define TMP_REG8 dl

# Result = *OP1 & 0x0FFFFFFF
# I could forego doing the binary AND and save a few bytes, but it wouldn't functionally be the same
read_memory:
    and OP1_REG, 0x0FFFFFFF # Basically limits ROM to reading first 16 MiB of VM
    mov RES_REG, dword ptr [OP1_REG]
    jmp go_back_to_loop_command

# *OP1 = OP2
write_memory:
    mov dword ptr [OP1_REG], OP2_REG
    jmp go_back_to_loop_command

# Write to PCI space
write_pci:
    cmp OP1_REG, 0x80000880
    jne continue_write_pci
    and OP2_REG, 0xFFFFFFFD
    continue_write_pci:

    # Have to use the opcode register for this one since out only works with eax, and we don't have a stack
    mov TMP_REG16, 0xCF8
    mov OPC_REG32, OP1_REG
    out TMP_REG16, OPC_REG32

    add TMP_REG8, 4 # effectively set it to 0xCFC
    mov OPC_REG32, OP2_REG
    out TMP_REG16, OPC_REG32

    jmp go_back_to_loop_command

# Read from PCI space
read_pci:
    mov OPC_REG32, OP1_REG
    mov TMP_REG16, 0xCF8
    out TMP_REG16, OPC_REG32

    add TMP_REG8, 4
    in OPC_REG32, TMP_REG16
    mov RES_REG, OPC_REG32

go_back_to_loop_command:
    jmp loop_command

# Binary AND result with OP1 and OR with OP2
and_then_or:
    and RES_REG, OP1_REG
    or RES_REG, OP2_REG
    jmp loop_command

# Shift the registers and then interpret the opcode
# op1 --> opcode
# op2 --> op1
# res --> op2
chain_command:
    mov OPC_REG32, OP1_REG
    mov OP1_REG, OP2_REG
    mov OP2_REG, RES_REG
    jmp begin_execute_command

# Do a jump if operand 1 != result
branch_jne:
    cmp RES_REG, OP1_REG
    je done_jne
# Add operand 2 to the command pointer
jump_offset:
    add CMD_REG, OP2_REG
done_jne:
    jmp loop_command

# Read from I/O port
write_io:
    mov TMP_REG32, OP1_REG
    mov OPC_REG32, OP2_REG
    out TMP_REG16, OPC_REG8
    jmp loop_command

# Write to I/O port
read_io:
    mov TMP_REG32, OP1_REG
    in OPC_REG8, TMP_REG16
    movsx RES_REG, OPC_REG8
    jmp loop_command

# Same as "and then or" but with the scratch register, and we set the result to it
and_then_or_scratch_reg:
    and SCR_REG, OP1_REG
    or SCR_REG, OP2_REG
    mov RES_REG, SCR_REG
    jmp loop_command

# Let's begin.
main16:
    # First set up the GDT (this is 16-bit x86, so the bytecode has to be written out)
    # o32 lgdt [cs:gdt_reference]
    .byte 0x66, 0x2E, 0x0F, 0x01, 0x16
    .short gdt_reference

    # There is code to set up the IDT, too, but it's not a valid IDT, so... uh... we don't need to do it
    # o32 lidt [cs:gdt_reference]
    # .byte 0x66, 0x2E, 0x0F, 0x01, 0x1E
    # .short gdt_reference

    # Enable protected mode
    # mov eax, cr0
    # or al, 1
    # mov cr0, eax
    .byte 0x0F, 0x20, 0xC0
    .byte 0x0C, 0x01
    .byte 0x0F, 0x22, 0xC0

    # Jump into main32
    # mp dword 0x0008:main32
    .byte 0x66, 0xEA
    .long main32
    .byte 0x08, 0x00

# Now we're in 32-bit mode
main32:
    # Set es, ds, and ss each to 0x10
    xor eax, eax
    mov al, 0x10
    mov ds, eax
    mov ss, eax
    mov es, eax

    # Run commands from ROM
    mov CMD_REG, (0xFF000080 - 0x9)

loop_command:
    # Advance 9 bytes
    add CMD_REG, 0x9

# Load the opcode
read_next_command:
    # Read the opcode
    xor OPC_REG32, OPC_REG32
    mov OPC_REG8, byte ptr [CMD_REG]
    
    # First operand
    mov OP1_REG, dword ptr [CMD_REG + 1]
    
    # Second operand
    mov OP2_REG, dword ptr [CMD_REG + 5]
    
    # Are we done?
    cmp OPC_REG8, 0xEE
    je finish_commands

begin_execute_command:
    # Greater than 18? Go to loop_command
    cmp OPC_REG8, 18
    ja loop_command

    # 0-9? Go to the thing
    cmp OPC_REG8, 9
    jbe execute_command

    # 16-18? Go to the thing
    cmp OPC_REG8, 16
    jae execute_command_16_to_18

    # 10-15? Go to loop_command
    jmp loop_command

execute_command_16_to_18:
    # Subtract 6, since the first opcode is 16 and we want the 16th opcode to be the 10th index
    sub OPC_REG8, 6

execute_command:
    # Get the function pointer as an offset from 0xFFFFFE00.
    mov TMP_REG32, TEXT_START_ADDR
    mov TMP_REG8, byte ptr [opcodes_functions + OPC_REG32]

    # Call it
    jmp TMP_REG32

finish_commands:
    # Initialize MTRRs (0x200-0x20F)
    mov ch, 2
    xor eax, eax
    xor ecx, ecx
    xor edx, edx

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
    mov esp, 0x8F000

#ifdef BIOS1
# This actually runs encrypt() for TEA to verify that the second stage bootloader is correct. This is NOT required to load anything - it is merely a verification.
# See https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm
#define TEA_START 0xFFFFD400
#define TEA_END 0xFFFFFC80

tea_verify_begin:
    mov ebp, TEA_START
    mov edi, TEA_END
    xor ecx, ecx
    mov eax, ebp
    mov ebx, edi
    
    mov dword ptr [esp + 0x1C], ecx
    mov dword ptr [esp + 0x18], esp
    mov dword ptr [esp + 0x14], edi

# Initialize more values here
tea_outer_loop:
    mov edx, dword ptr [ebp]
    mov esi, dword ptr [ebp + 0x4]
    
    add esp, 0x14
    push esi # esp + 0x10 - k3
    push edx # esp + 0xC - k2
    push ebx # esp + 0x8 - k1
    push eax # esp + 0x4 - k0
    push ecx # esp + 0x0 - zero out sum
    
    # Set our counter to 32
    mov cl, 0x20

# Run TEA encryption (loop 32 times)
tea_inner_loop:
    # sum += delta (golden ratio)
    add dword ptr [esp], 0x9E3779B9
    
    # v0
    mov edx, ebx
    mov esi, ebx
    add edx, dword ptr [esp]
    shl esi, 0x4
    add esi, dword ptr [esp + 0x4]
    xor edx, esi
    mov esi, ebx
    shr esi, 0x5
    add esi, dword ptr [esp + 0x8]
    xor edx, esi
    add eax, edx
    
    # v1
    mov edx, eax
    mov esi, eax
    add edx, dword ptr [esp]
    shl esi, 0x4
    add esi, dword ptr [esp + 0xC]
    xor edx, esi
    mov esi, eax
    shr esi, 0x5
    add esi, dword ptr [esp + 0x10]
    xor edx, esi
    add ebx, edx
    
    loop tea_inner_loop # do that 32 times

# Keep going...?
tea_outer_loop_continued:
    xchg dword ptr [esp + 0x14], eax
    xchg dword ptr [esp + 0x18], ebx
    add ebp, dword ptr [esp + 0x1C]
    xor dword ptr [esp + 0x1C], 0x8
    cmp ebp, edi
    jb tea_outer_loop

# Compare against the hash. If it matches, load into the BIOS.
tea_verify:
    add esp, (0xC + 0x8)
    push ebx
    push eax
    
    ## Check hashes
    mov cl, 4
    mov esi, esp
    mov edi, OFFSET tea_hash
    rep cmpsd dword ptr [esi], dword ptr [edi]
    jne error_handler
    
    # Done~
    jmp 0xFFFFD400
    
# This is the hash we expect (verifies it's correct)
tea_hash:
    .long 0xAF6740C7, 0xDAD52A5D, 0xC5D43293, 0x68BFF4E8
    
#endif

#ifdef BIOS0

decode_arc4:
    # ARCFOUR KSA
    xor eax, eax
    xor ecx, ecx # set to 0 (we're going to let this underflow until we hit 0 again)
    mov edx, esp
    arcfour_key_schedule_loop:
    mov byte ptr [edx], al
    inc al
    inc edx
    dec cl
    jnz arcfour_key_schedule_loop

    # Load our key
    xor edi, edi
    xor ebx, ebx
    mov ebp, OFFSET arc4_key

    arcfour_key_loop:
    mov al, byte ptr [ecx + ebp]
    mov dl, byte ptr [edi + esp]
    add bl, al
    add bl, dl
    mov al, byte ptr [ebx + esp]
    mov byte ptr [edi + esp], al
    inc edi
    mov byte ptr [ebx + esp], dl
    inc ecx
    and ecx, 0xF # prevent ecx from going above 0x10
    arcfour_key_loop_cmp:
    cmp edi, 0x100
    jc arcfour_key_loop
    xor ecx, ecx
    xor edx, edx
    xor edi, edi
    mov ebp, 0x6000

    # Addresses to hold our input/output for when we do encryption
    #define ARCFOUR_ENCRYPTED_DATA_ADDR 0xFFFF9E00
    #define ARCFOUR_DECRYPTED_DATA_ADDR 0x00090000

    # Now actually decrypt
    # Encrypted is stored at 0xFFFF9E00
    # Decrypted is stored at 0x00090000 - this is where we're going to jump to
    arcfour_decrypt_loop:
    inc cl
    mov al, byte ptr [esp + ecx]
    add dl, al
    mov bl, byte ptr [esp + edx]
    mov byte ptr [esp + ecx], bl
    mov byte ptr [esp + edx], al
    add al, bl
    mov bl, byte ptr [ARCFOUR_ENCRYPTED_DATA_ADDR + edi]
    mov al, byte ptr [esp + eax]
    xor bl, al
    mov byte ptr [ARCFOUR_DECRYPTED_DATA_ADDR + edi], bl
    inc edi
    dec ebp
    jnz arcfour_decrypt_loop

    # Do a sanity check
    cmp dword ptr [0x95FE4], 0x7854794A
    jne error_handler
    jmp dword ptr [ARCFOUR_DECRYPTED_DATA_ADDR]

# Decryption key
arc4_key:
    .byte 0x27, 0x45, 0xA9, 0x10, 0x39, 0x7E, 0x6A, 0xA6, 0x86, 0xFB, 0x4B, 0x1A, 0x4B, 0xA9, 0x0F, 0xD2
#endif

# Global descriptor table
gdt_table:
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x9B, 0xCF, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x93, 0xCF, 0x00

# Global descriptor reference
gdt_reference:
    # Limit
    .short 0x0018

    # Base
    .long gdt_table

# Error handling trap (failed sanity check - exception)
error_handler:
    jmp error_handler

# Reset vector (0xFFFFFFF0)
# This is where execution starts. We have exactly 16 bytes to work with this section.
.section .reset_vector

# This is our entry point.
entry_point:
    # 16-bit jmp to main
    .byte 0xE9
    .word (main16-(0xFFF0+3))


# Store the opcode's respective functions as 8-bit offsets from text_start, which is 0xFFFFFE00
opcodes_functions:
    # 0-1
    .byte (loop_command - text_start)
    .byte (loop_command - text_start)
    
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
