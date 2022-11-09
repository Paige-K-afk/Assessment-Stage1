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

# WRITE INTHEX CODE:
HexChars:	.ascii "0123456789ABCDEF"
# Output the value passed on the stack to the screen using the specified base
#

#define     number      6
#define     base        4
#define     endofstring -2

cons_write_number:
    pushw   %bp                 # Save existing frame pointer
    movw    %sp, %bp            # Setup our frame pointer
    subw    $18, %sp            # Reserve space for our string buffer
    pushw   %ax                 # Save the registers we will trash
    pushw   %bx
    pushw   %cx
    pushw   %dx
    pushw   %si
    pushw   %di

    movw    %bp, %si
    subw    $3, %si
    movb    $0, endofstring(%bp)    # Insert end of string indicator (0)    
    movw    number(%bp), %ax
	
getdigit:
	xor		%dx, %dx                # Divide number by base
	movw	base(%bp), %cx
	div		%cx
    movw    %dx, %di                # Convert remainder to hex character
    movb    HexChars(%di), %dl      # and stpre in buffer
	movb	%dl, (%si)
	dec		%si
	cmpw	$0, %ax                 # Have we extracted all digits?
	jne		getdigit
	inc		%si
	call	cons_write              # Output the string

    popw    %di                     # Restore the registers
    popw    %si
    popw    %dx
    popw    %cx
    popw    %bx
    popw    %ax
    movw    %bp, %sp                # Delete the local variables
    popw    %bp
    ret     $4                      # Return, removing paramters from stack


	ret
	
IntBuffer:   .string "     "
# END OF WRITE INTHEX CODE.


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
    .word 0
sy:
    .word 0
err:
    .word 0
e2:
    .word 0
delta_y:
    .word
delta_x:
    .word

abs_function:
    # value to absolute is in ax. Load bearing useless function.
    cmp $0, %ax
    jns abs_pos_ax
    movw $-1, %dx
    imul %dx # negate %ax (mul's do ax * target, store in ax)
    ret
    abs_pos_ax:
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
    movw (x1), %bx
    movw (x0), %ax
    sub %bx, %ax # ax := (x1 - x0) 
    # better equivalent of call abs_function # absolute and store ax to dx, which is in ax right now
    cmp $0, %ax
    jns xabs_pos_ax
    movw $-1, %dx
    imul %dx # negate %ax (mul's do ax * target, store in ax)
    xabs_pos_ax:
    movw %ax, (delta_x) # store and save it in ax

    # dy := abs(y1 - y0)
    movw (y1), %bx
    movw (y0), %ax
    sub %bx, %ax # dy := abs(y1 - y0) 
    # better equivalent of call abs_function # absolute and store dy to cx, which is in ax right now
    cmp $0, %ax
    jns yabs_pos_ax
    movw $-1, %dx
    imul %dx # negate %ax (mul's do ax * target, store in ax)
    yabs_pos_ax:
    movw %ax, (delta_y) # store and save it to %delta x


    # sx sy section (this has been fixed. no touchy)
    # . if x0 < x1 then sx := 1 else sx := -1
    movw (x0), %ax
    movw (x1), %bx
    movw $1, (sx)
    cmp %bx, %ax  # (it does second < first.)
    jl x0_lessthan # if x0 < x1, cary flag wil be 1. jc jumps if cary flag = 1.
    movw $-1, (sx) # . else sx := -1 
    x0_lessthan: # then sx := 1 as it's unchanged.

    # . if y0 < y1 then sy := 1 else sy := -1
    movw (y0), %ax
    movw (y1), %bx
    movw $1, (sy) 
    cmp %bx, %ax  # (it does second < first.)
    jl y0_lessthan # if y0 < y1 , cary flag will be 1. jc jumps if cf = 1.
    movw $-1, (sy) # . else sy := -1 
    y0_lessthan: # then sy := 1 as it's unchanged

#    pushw  (delta_x)
#    push   $10
#    call    cons_write_number
#    call cons_write_crlf
#    pushw  (delta_y)
#    push   $10
#    call cons_write_number
#    call cons_write_crlf
#    pushw  (sx)
#    push   $10
#    call    cons_write_number
#    call cons_write_crlf
#    pushw  (sy)
#    push   $10
#    call cons_write_number
#    call cons_write_crlf
#    call cons_write_crlf

    # err = dx - dy
    movw (delta_x), %ax
    movw (delta_y), %bx
    neg %bx 
    ADD %ax, %bx # err := dx - dy 
    movw %bx, (err) 

    draw:

    call setPixel # setPixel(0x,0y,colour)
   
    # . if x0 = x1 and y0 = y1 exit loop
    # is x equal
    movw (x1), %ax # move x1 to register so it can actualy be compared to x0
    cmp (x0), %ax # becase cmp can't take two literal memory adresses, one has to be moved into a register first.
    # 0x is destination, x1 is source. if zero flag is not set, jump.
    jne xy_not_equal_cont  # . if x0 = x1, and y0 - y1, exit loop, so if it's not equal here (zf = 0), we can skip the y check.
    # is y equal
    movw (y1), %ax # move y1 to register so it can actualy be compared to y0
    cmp (y0), %ax
    # y0 is destination. y1 is source. if equal, zf is 1. if zf is 1, jump.
    je end_draw  # . y0 = y1 exit loop
    xy_not_equal_cont:

    # calculate e2
    movw (err), %dx
    movw $2, %ax
    imul %dx  # %dx stores e2 which is :  e2 := 2 * err. result is in ax.
    movw %ax, (e2) # move the target of mul to e2.

    # restore bx and cx to delta x and y at the start of the function that needs it
    movw (delta_y), %cx
    neg %cx
    
    cmp %cx, (e2) # (it does second > first.)
    # cmp (e2), %cx # reversed
    jg e2_greaterThan_negDy # if this is jge, it'll make it to yellow, then fill the screen with yellow as a diagonal.
    jmp e2_notGreaterThan_negDy
    e2_greaterThan_negDy:   
    movw (err), %ax
    # by adding err and negative dy, we save ourselves the trouble of figuring out which way around this needs to be.
    ADD %cx, %ax  # err := err - dy ( notTarget (err) - target %ax (deltaY))
    movw %ax, (err) # save ax to err
    movw (x0), %ax # move x0 into register
    ADD (sx), %ax # add sx to al register
    movw %ax, (x0) # move new result back into x0
    e2_notGreaterThan_negDy: # end if
    
    # issues start here.
    # restore bx and cx to delta x and y
    movw (delta_x), %bx

    cmp %bx, (e2) # (it does second > first.)
    # cmp (e2), %bx # reversed
    jl e2_lessThan_Dx # if jle, it tries to make vertical lines, giving the screen a bunch of widely spaced vertical lines.
    jmp e2_notLessThan_Dx
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

    # The dot
    movw $5, %si # x0
    movw $5, %ax # y0
    movw $5, %bx # x1
    movw $5, %cx # y1
    movb $13 , %dl # line_colour
    call cons_drawline

    # Short white line 1
    movw $15, %si # x0
    movw $15, %ax # y0
    movw $25, %bx # x1
    movw $25, %cx # y1
    movb $15 , %dl # line_colour
    call cons_drawline

    # Short while line 2
    movw $25, %si # x0
    movw $15, %ax # y0
    movw $15, %bx # x1
    movw $25, %cx # y1
    movb $15 , %dl # line_colour
    call cons_drawline

    # Long red line
    movw $100, %si # x0
    movw $100, %ax # y0
    movw $200, %bx # x1
    movw $200, %cx # y1
    movb $4 , %dl # line_colour
    call cons_drawline

    # Long light magenta line
    movw $200, %si # x0
    movw $100, %ax # y0
    movw $100, %bx # x1
    movw $200, %cx # y1
    movb $13 , %dl # line_colour
    call cons_drawline

    # diagonal Light red line (x=y)
    movw $150, %si # x0
    movw $50, %ax # y0
    movw $180, %bx # x1
    movw $80, %cx # y1
    movb $12 , %dl # line_colour
    call cons_drawline

    # diagonal Light blue line
    movw $100, %si # x0
    movw $50, %ax # y0
    movw $120, %bx # x1
    movw $180, %cx # y1
    movb $13 , %dl # line_colour

    # Horisontal green line
    movw $0, %si # x0
    movw $0, %ax # y0
    movw $10, %bx # x1
    movw $0, %cx # y1
    movb $10 , %dl # line_colour
    call cons_drawline

    # vertical yellow line
    movw $0, %si # x0
    movw $0, %ax # y0
    movw $0, %bx # x1
    movw $11, %cx # y1
    movb $14 , %dl # line_colour
    call cons_drawline
    
    # Horisontal light cyan line
    movw $50, %si # x0
    movw $50, %ax # y0
    movw $100, %bx # x1
    movw $50, %cx # y1
    movb $11 , %dl # line_colour
    call cons_drawline
    
    # Horisontal yellow line
    movw $50, %si # x0
    movw $40, %ax # y0
    movw $100, %bx # x1
    movw $40, %cx # y1
    movb $14 , %dl # line_colour
    call cons_drawline

    # short diagonal magenta line
    movw $150, %si # x0
    movw $150, %ax # y0
    movw $160, %bx # x1
    movw $160, %cx # y1
    movb $5 , %dl # line_colour
    call cons_drawline




endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_message:     
    .string "Boot Loader Stage 2 loaded"             

testmessage:
    .string "15 is less"
testmessage2:
    .string "25 is less"