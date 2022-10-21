# When the PC starts, the processor is essentially emulating an 8086 processor, i.e. 
# a 16-bit processor.  So our initial boot loader code is 16-bit code that will 
# eventually switch the processor into 32-bit mode.

# This code is linked to assume a starting address of 0x7C00 which is where the BIOS
# will load a boot segment.

.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start

# Write to the console using BIOS.
# 
# Input: SI contains the address of the null-terminated string to be displayed

cons_write:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_crlf:
    movb    $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret    

# Output the 16-bit value in BX to the screen has a 4 digit hex value	
#
# Input:  BX = Value to output	

HexChars:	.ascii "0123456789ABCDEF"

cons_write_hex:
	movw	$4, %cx
    movb    $0x0E, %ah
	
hexloop:
    rol     $4, %bx
    movw    %bx, %si
    and     $0x000F, %si
    movb    HexChars(%si), %al
	int		$0x10
	loop	hexloop
	ret

# Output the value in BX as an unsigned integer
#
# Input: BX = Value to output
divide_by_ten:
    xor %dx, %dx
    movw $10, %cx
    div %cx                     # remainder will be in dx
    ret	

cons_write_int:
    movw    $IntBuffer + 4, %si
    movw    %bx, %ax
	
getdigit:
	call divide_by_ten
	addb	$48, %dl
	movb	%dl, (%si)
	dec		%si
	cmp		$0, %ax
	jne		getdigit
	inc		%si
	call	cons_write
	ret
	
IntBuffer:   .string "     "

# COMMENT: if statement to go between cons_write_int and cons_write_hex
# Comment: constant definitions for the offsets to the parameters and variables
#define a  4
#define b   6
#define x   -4
#define y   -2
cons_write_number:
    # values in stack
    # stack access
    pushw %bp
    movw %sp, %bp
    subw $4, %sp
    movw a(%bp), %bx    # the constant a is used to get to the seccond param
    # the first value on the stack we want is at offset 6 (parameter 1)
    # the seccond we want is at offset 4 (parameter 2)
    # use the seccond variable in a comp to determine next call
    call cons_write_int         # see if it's the right one
    call cons_write_crlf             # debug
    cmp $10, %bx
    je prep_int_stack
    cmp $16, %bx
    je prep_hex_stack
    movw $base_not_found_msg, %si       # display when second digit not applicable
    call cons_writeline
cons_write_number_done:
    # COMMENT stack cleanup
    movw %bp, %sp
    popw %bp
    ret     $4
prep_int_stack:
    # COMMENT get value at offset 6 into bx
    movw b(%bp), %bx    # the constant b is used to get the first param
    call cons_write_int
    # COMMENT stack cleanup
    movw %bp, %sp
    popw %bp
    ret     $4
prep_hex_stack:
    # get value at offset 6 into bx
    movw b(%bp), %bx    # the constant b is used to get the first param
    call cons_write_hex
    # COMMENT stack cleanup
    movw %bp, %sp
    popw %bp
    ret     $4

real_start:
    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it hear since DL might get trashed

    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    movw    $booted_from_msg, %si
    call    cons_write

    movb    (boot_device), %dl
    cmp     $0x80, %dl
    jge     harddrive

    movw    $fd, %si
    jmp     finish

harddrive:
    movw    $hd, %si

finish:
    call    cons_writeline

    # Test cons_write_int and cons_write_hex

    movw    $65535, %bx         # Display numbers in hex
    call    cons_write_hex
    call    cons_write_crlf
    movw    $4660, %bx
    call    cons_write_hex
    call    cons_write_crlf
    movw    $0, %bx
    call    cons_write_hex
    call    cons_write_crlf
    movw    $65535, %bx         # Display unsigned short numbers
    call    cons_write_int
    call    cons_write_crlf
    movw    $1234, %bx
    call    cons_write_int
    call    cons_write_crlf
    movw    $0, %bx
    call    cons_write_int
    call    cons_write_crlf
    # branch with stack stuff
    movw $290, %bx
    call    cons_write_int      # for debug
    call    cons_write_crlf     # for debug
    pushw %bx
    movw $10, %bx
    call    cons_write_int      # for debug
    call    cons_write_crlf     # for debug
    pushw %bx
    call cons_write_number
    call cons_write_crlf  

endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_device:
    .byte   0

boot_message:     
    .string "Boot Loader Stage 2 loaded"             
booted_from_msg:
    .string "Booting from "
fd: .string "floppy disk"
hd: .string "hard drive"
base_not_found_msg:
    .string "base not found"
