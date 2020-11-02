;# Fancy Mouse Boot ROM
;# Copyright (C) 2020 SnowyMouse

;# Note we're using Intel syntax
.intel_syntax noprefix

;# Main code (0xFFFFFE00)
.text

text_start:

#define TEXT_START_ADDR 0xFFFFFE00

;# Operand 1 register
#define OP1_REG edi

;# Operand 2 register
#define OP2_REG esi

;# Result register
#define RES_REG ebp

;# Opcode register
#define OPC_REG8 al
#define OPC_REG32 eax

;# Scratch register
#define SCR_REG ecx

;# Command pointer
#define CMD_REG ebx

;# Temporary value register
#define TMP_REG32 edx
#define TMP_REG16 dx
#define TMP_REG8 dl

;# Addresses to hold our input/output for when we do encryption
#define ENCRYPTED_DATA_ADDR 0xFFFF9E00
#define DECRYPTED_DATA_ADDR 0x00090000

;# Result = *OP1 & 0x0FFFFFFF
;# I could forego doing the binary AND and save a few bytes, but it wouldn't functionally be the same
read_memory:
    and OP1_REG, 0x0FFFFFFF ;# Basically limits ROM to reading first 16 MiB of VM
    mov RES_REG, dword ptr [OP1_REG]
    ret

;# *OP1 = OP2
write_memory:
    mov dword ptr [OP1_REG], OP2_REG
    ret

;# Write to PCI space
write_pci:
    cmp OP1_REG, 0x80000880
    jne continue_write_pci
    and OP2_REG, 0xFFFFFFFD
    continue_write_pci:

    ;# Have to use the opcode register for this one since out only works with eax, and we don't have a stack
    mov TMP_REG16, 0xCF8
    mov OPC_REG32, OP1_REG
    out TMP_REG16, OPC_REG32

    add TMP_REG8, 4 ;# effectively set it to 0xCFC
    mov OPC_REG32, OP2_REG
    out TMP_REG16, OPC_REG32

    ret

;# Read from PCI space
read_pci:
    mov OPC_REG32, OP1_REG
    mov TMP_REG16, 0xCF8
    out TMP_REG16, OPC_REG32

    add TMP_REG8, 4
    in OPC_REG32, TMP_REG16
    mov RES_REG, OPC_REG32

    ret

;# Binary AND result with OP1 and OR with OP2
and_then_or:
    and RES_REG, OP1_REG
    or RES_REG, OP2_REG
    ret

;# Shift the registers and then interpret the opcode
;# op1 --> opcode
;# op2 --> op1
;# res --> op2
chain_command:
    mov OPC_REG32, OP1_REG
    mov OP1_REG, OP2_REG
    mov OP2_REG, RES_REG
    jmp begin_execute_command

;# Do a jump if operand 1 != result
branch_jne:
    cmp RES_REG, OP1_REG
    je done_jne
;# Add operand 2 to the command pointer
jump_offset:
    add CMD_REG, OP2_REG
done_jne:
    ret

;# Read from I/O port
write_io:
    mov TMP_REG32, OP1_REG
    mov OPC_REG32, OP2_REG
    out TMP_REG16, OPC_REG8
    ret

;# Write to I/O port
read_io:
    mov TMP_REG32, OP1_REG
    in OPC_REG8, TMP_REG16
    movsx RES_REG, OPC_REG8
    ret

;# Same as "and then or" but with the scratch register, and we set the result to it
and_then_or_scratch_reg:
    and SCR_REG, OP1_REG
    or SCR_REG, OP2_REG
    mov RES_REG, SCR_REG
    ret

;# Let's begin.
main16:
    ;# First set up the GDT (this is 16-bit x86, so the bytecode has to be written out)
    .byte 0x66, 0x2E, 0x0F, 0x01, 0x16
    .short gdt_reference

    ;# There is code to set up the IDT, too, but it's not a valid IDT, so... uh... we don't need to do it
    ;# .byte 0x66, 0x2E, 0x0F, 0x01, 0x1E
    ;# .short gdt_reference

    ;# Enable protected mode
    .byte 0x0F, 0x20, 0xC0
    .byte 0x0C, 0x01
    .byte 0x0F, 0x22, 0xC0

    ;# Jump into main32
    .byte 0x66, 0xEA
    .long main32
    .byte 0x08, 0x00

;# Now we're in 32-bit mode
main32:
    ;# Set es, ds, and ss each to 0x10
    xor eax, eax
    mov al, 0x10
    mov ds, eax
    mov ss, eax
    mov es, eax

    ;# Run commands from ROM
    mov CMD_REG, 0xFF000080

;# Load the opcode
read_next_command:
    ;# Read the opcode
    mov OPC_REG8, byte ptr [CMD_REG]
    ;# First operand
    mov OP1_REG, dword ptr [CMD_REG + 1]
    ;# Second operand
    mov OP2_REG, dword ptr [CMD_REG + 5]

begin_execute_command:
    ;# Are we done?
    cmp OPC_REG8, 0xEE
    je finish_commands

    ;# Greater than 18? Go to loop_command
    cmp OPC_REG8, 18
    ja loop_command

    ;# Less than 2? Go to loop_command
    cmp OPC_REG8, 2
    jb loop_command

    ;# 2-9? Go to the thing
    cmp OPC_REG8, 9
    jbe execute_command_2_to_9

    ;# 16-18? Go to the thing
    cmp OPC_REG8, 16
    jae execute_command_16_to_18

    ;# 10-15? Go to loop_command
    jmp loop_command

execute_command_2_to_9:
    ;# Add 6. We're going to subtract (2+6) after this, so we effectively subtract 2.
    add OPC_REG8, 6

execute_command_16_to_18:
    ;# Subtract 2+6, since the first opcode is 16 and we want the 16th opcode to be the 8th
    sub OPC_REG8, (2+6)

execute_command:
    ;# Convert the 8-bit opcode to a 32-bit one
    movsx OPC_REG32, OPC_REG8

    ;# Get the function pointer as an offset from 0xFFFFFE00.
    mov TMP_REG32, TEXT_START_ADDR
    mov TMP_REG8, byte ptr [opcodes_functions + OPC_REG32]

    ;# Set our stack pointer to data that we haven't initialized yet so we can return from functions we call (if we want to)
    mov esp, (DECRYPTED_DATA_ADDR + 0x1000)

    ;# Call it
    call TMP_REG32

loop_command:
    ;# Advance 9 bytes
    add CMD_REG, 0x9

    jmp read_next_command

finish_commands:
    ;# Initialize MTRRs (0x200-0x20F)
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
    mov eax, ebx
    wrmsr

    ;# Enable caching
    mov eax, cr0
    and eax, 0x9FFFFFFF
    mov cr0, eax

    ;# ARCFOUR KSA
    mov eax, 0x3020100
    mov cl, 0x40
    mov esi, 0x8F000
    mov edx, esi
    arcfour_key_schedule_loop:
    mov dword ptr [edx], eax
    add edx, 0x4
    add eax, 0x4040404
    dec cl
    jnz arcfour_key_schedule_loop

    ;# Load our key
    xor ecx, ecx
    xor edi, edi
    xor ebx, ebx
    lea ebp, key

    arcfour_key_loop:
    mov al, byte ptr [ebp + ecx]
    mov dl, byte ptr [edi + esi]
    add bl, al
    add bl, dl
    mov al, byte ptr [ebx + esi]
    mov byte ptr [edi + esi], al
    inc edi
    mov byte ptr [ebx + esi], dl
    inc ecx
    cmp ecx, 0x10
    jne arcfour_key_loop_cmp
    xor ecx, ecx
    arcfour_key_loop_cmp:
    cmp edi, 0x100
    jc arcfour_key_loop
    xor ecx, ecx
    xor edx, edx
    xor edi, edi
    xor eax, eax
    mov esi, 0x8F000
    mov ebp, 0x6000

    ;# Now actually decrypt
    ;# Encrypted is stored at 0xFFFF9E00
    ;# Decrypted is stored at 0x00090000 - this is where we're going to jump to
    arcfour_decrypt_loop:
    inc cl
    mov al, byte ptr [esi + ecx]
    add dl, al
    mov bl, byte ptr [esi + edx]
    mov byte ptr [esi + ecx], bl
    mov byte ptr [esi + edx], al
    add al, bl
    mov bl, byte ptr [ENCRYPTED_DATA_ADDR + edi]
    mov al, byte ptr [esi + eax]
    xor bl, al
    mov byte ptr [DECRYPTED_DATA_ADDR + edi], bl
    inc edi
    dec ebp
    jnz arcfour_decrypt_loop

    ;# Do a sanity check
    cmp dword ptr [0x95FE4], 0x7854794A
    jne error_handler

    jmp dword ptr [DECRYPTED_DATA_ADDR]

;# Decryption key
key:
    .byte 0x27, 0x45, 0xA9, 0x10, 0x39, 0x7E, 0x6A, 0xA6, 0x86, 0xFB, 0x4B, 0x1A, 0x4B, 0xA9, 0x0F, 0xD2

;# Global descriptor table
gdt_table:
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x9B, 0xCF, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x93, 0xCF, 0x00

;# Global descriptor reference
gdt_reference:
    ;# Limit
    .short 0x0018

    ;# Base
    .long gdt_table

;# Reset vector (0xFFFFFFF0)
;# This is where execution starts. We have exactly 16 bytes to work with this section.
.section .reset_vector

;# This is our entry point.
entry_point:
    ;# 16-bit jmp to main
    .byte 0xE9
    .word (main16-(0xFFF0+3))


;# Store the opcode's respective functions as 8-bit offsets from text_start, which is 0xFFFFFE00
opcodes_functions:
    ;# 2-9
    .byte (read_memory - text_start)
    .byte (write_memory - text_start)
    .byte (write_pci - text_start)
    .byte (read_pci - text_start)
    .byte (and_then_or - text_start)
    .byte (chain_command - text_start)
    .byte (branch_jne - text_start)
    .byte (jump_offset - text_start)
    ;# 16-18
    .byte (and_then_or_scratch_reg - text_start)
    .byte (write_io - text_start)
    .byte (read_io - text_start)

;# Error handling trap (failed sanity check - exception)
error_handler:
    jmp error_handler
