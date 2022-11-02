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
    .byte 0
sx:
    .byte 0
sy:
    .byte 0
err:
    .word 0
e2:
    .word 0
delta_y:
    .word
delta_x:
    .word

abs_function:
# value to absolute is in ax
cmp $0, %ax
je abs_minus_ax
ret
abs_minus_ax:
neg %ax # negate %ax
ret

setPixel:
     # call switch_to_vga
    movb $0x0C, %ah     # AH 0x0C
    movb (line_colour), %al # AL The colour for the pixel (see below)
    movb $0, %bh # BH The video page number (should be set to 0)
    movw (x0), %cx # CX Column number (starting from 0)
    movw (y0), %dx # DX Row number (starting from 0)
    int $0x10

ret

cons_drawline:
    # draw a line between any two points on the screen using a specified colour. Each point has an x and y coordinate.
    # each point is a parameter.
    movw %si, (x0)
    movw %ax, (y0)
    movw %bx, (x1)
    movw %cx, (y1)
    movb %dl, (line_colour)

    # clear registers as we're pulling from the variables from now on.
    xorw %si, %si
    xorw %ax, %ax
    xorw %bx, %bx
    xorw %cx, %cx
    xorw %dx, %dx

    # dx := abs(x1 - x0)
    movw (x1), %ax
    movw (x0), %bx
    sub %bx, %ax # ax := (x1 - x0)  
    call abs_function # absolute and store ax to dx, which is in ax right now
    movw %ax, (delta_x) # store and save it in ax
    # dy := abs(y1 - y0)
    movw (y1), %ax
    movw (y0), %bx
    sub %bx, %ax # dy := abs(y1 - y0) 
    call abs_function # absolute and store dy to cx, which is in ax right now
    movw %ax, (delta_y) # store and save it to %delta x

    # . if x0 < x1 then sx := 1 else sx := -1
    movw (x1), %ax
    movw (x0), %bx
    cmp %bx, %ax # destination 0x, source x1. 
    # cmp %ax, %bx # reversed
    jl x0_lessthan # if x0 < x1, cary flag wil be 1. jc jumps if cary flag = 1.
    movb $-1, (sx) # . else sx := -1 
    jmp x0_done
    x0_lessthan:
    movb $1, (sx) # then sx := 1
    x0_done:
    # . if y0 < y1 then sy := 1 else sy := -1
    movw (y1), %ax
    movw (y0), %bx
    cmp %bx, %ax # destination bx (y0), source ax (y1)
    # cmp %ax, %bx # reversed
    jl y0_lessthan # if y0 < y1 , cary flag will be 1. jc jumps if cf = 1.
    movb $-1, (sy) # . else sy := -1 
    jmp y0_done
    y0_lessthan:
    movb $1, (sy) # then sy := 1
    y0_done:

    # err = dx - dy
    movw (delta_x), %ax
    movw (delta_y), %bx
    sub %bx, %ax # err := dx - dy 
    movw %ax, (err) 


    draw:

    call setPixel # setPixel(0x,0y,colour)
   
    # . if x0 = x1 and y0 = y1 exit loop
    # is x equal
    movw (x1), %ax # move x1 to register so it can actualy be compared to x0
    cmp (x0), %ax # becase cmp can't take two literal memory adresses, one has to be moved into a register first.
    # cmp %ax, (x0) # reversed
    # 0x is destination, x1 is source. if zero flag is not set, jump.
    # je end_draw # this is here to help see what is broken.
    jne xy_not_equal_cont  # . if x0 = x1, and y0 - y1, exit loop, so if it's not equal here (zf = 0), we can skip the y check.
    # is y equal
    movw (y1), %ax # move y1 to register so it can actualy be compared to y0
    cmp (y0), %ax
    # cmp %ax, (y0) # reversed
    # y0 is destination. y1 is source. if equal, zf is 1. if zf is 1, jump.
    je end_draw  # . y0 = y1 exit loop
    xy_not_equal_cont:

    # calculate e2
    movw (err), %dx
    movw $2, %ax
    mul %dx  # %dx stores e2 which is :  e2 := 2 * err. result is in ax.
    movw %ax, (e2) # move the target of mul to e2.

    # restore bx and cx to delta x and y at the start of the function that needs it
    movw (delta_y), %cx

    neg %cx
    
    cmp (e2), %cx # (e2) is destination, %cx is source. if e2> -dy
    # cmp %cx, (e2) # reversed
    jg e2_greaterThan_negDy
    jmp e2_notGreaterThan_negDy
    e2_greaterThan_negDy:
    movw (err), %ax # moves err to ax
    SUB (delta_y), %ax  # err := err - dy (target %ax - notTarget (deltaY))
    movw %ax, (err) # save ax to err
    movw (x0), %ax # move x0 into register
    ADD (sx), %ax # add sx to al register
    movw %ax, (x0) # move new result back into x0
    e2_notGreaterThan_negDy: # end if
    
    # restore bx and cx to delta x and y
    movw (delta_x), %bx

    cmp (e2), %bx # (e2) is destination, %bx is source. if e2<dx
    # cmp %bx, (e2) #reversed
    jl e2_lessThan_Dx
    jmp e2_lessThan_Dx
    e2_lessThan_Dx:
    movw (err), %ax
    ADD (delta_x), %ax # err := err + dx
    movw %ax, (err)
    movw (y0), %ax # move y0 into register
    ADD (sy), %ax # add sy to ax register 
    movw %ax, (y0) # move ax back into y0
    e2_notLessThan_Dx: # end if

    jmp draw
    end_draw:
    ret
    

real_start:
    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    call switch_to_vga

    movw $15, %si # x0
    movw $15, %ax # y0
    movw $25, %bx # x1
    movw $25, %cx # y1
    movb $15 , %dl # line_colour
    call cons_drawline

    movw $10, %si # x0
    movw $10, %ax # y0
    movw $200, %bx # x1
    movw $200, %cx # y1
    movb $4 , %dl # line_colour
    call cons_drawline

    movw $200, %si # x0
    movw $200, %ax # y0
    movw $10, %bx # x1
    movw $10, %cx # y1
    movb $13 , %dl # line_colour
    call cons_drawline

    
    movw $50, %si # x0
    movw $50, %ax # y0
    movw $100, %bx # x1
    movw $50, %cx # y1
    movb $11 , %dl # line_colour
    call cons_drawline
    
    movw $50, %si # x0
    movw $40, %ax # y0
    movw $100, %bx # x1
    movw $40, %cx # y1
    movb $14 , %dl # line_colour
    call cons_drawline

endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_message:     
    .string "Boot Loader Stage 2 loaded"             

