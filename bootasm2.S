# Second stage of the boot loader

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

switch_to_vga:
    movb $0, %ah
    movb $0x13, %al
    int $0x10
    ret

x0:
    .word 0
y0:
    .word 0
x1:
    .word 0
y1:
    .word 0
line_colour:
    .word 0
sx:
    .byte 0
sy:
    .byte 0
err:
    .word 0

abs_function:
# value to absolute is in ax
cmp $0, %ax
je abs_minus_ax
ret
abs_minus_ax:
neg %ax # negate %ax
ret

cons_drawline:
    # draw a line between any two points on the screen using a specified colour. Each point has an x and y coordinate.
    # each point is a parameter.
    movw %ax, (x0)
    movw %bx, (y0)
    movw %cx, (x1)
    movw %dx, (y1)
    movw %si, (line_colour)

    movw (x1), %ax
    movw (x0), %bx
    cmp %bx, %ax
    jg x0_greater # if x0 < x1  ||aka: x1 > x0
    movb $-1, (sx) # . else sx := -1 
    jmp x0_done
    x0_greater:
    movb $1, (sx) # then sx := 1
    x0_done:
    sub %bx, %ax # dx := (x1 - x0) 
    call abs_function # absolute and store dx to dx, which is in ax right now
    movw %ax, %dx

    movw (y1), %ax
    movw (y0), %bx
    cmp %bx, %ax
    jg y0_greater # if x0 < x1 
    movb $-1, (sy) # . else sy := -1 
    jmp y0_done
    y0_greater:
    movb $1, (sy) # then sx := 1# then sy := 1
    y0_done:
    sub %bx, %ax # dy := (y1 - y0)
    call abs_function # absolute and store dy to cx, which is in ax right now
    movw %ax, %cx

    movw %dx, %bx
    sub %cx, %bx
    movw %bx, err # err := dx - dy 



    draw:
    # dx is stored in dx, dy is stored in cx.
    # setPixel(0x,0y,colour)


    jmp draw
    end_draw:
    ret
    

real_start:
    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    call switch_to_vga

    movw $10, %ax # x0
    movw $10, %bx # y0
    movw $200, %cx # x1
    movw $200, %dx # y1
    movw $4 , %si # line_colour
    call cons_drawline

endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_message:     
    .string "Boot Loader Stage 2 loaded"             

