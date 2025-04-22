.data
clear_screen: .asciz "\033[2J\n"
hide_cursor: .asciz "\033[?25l"
show_cursor: .asciz "\033[?25h"
test_msg: .asciz "test\n"
termios: .skip 100
saved_termios: .skip 100
input_buffer: .skip 1

space: .asciz "   "
empty: .asciz "\033[38;5;130m.\033[0m"		// brown .
snake: .asciz "\033[32m@\033[0m"			// green @
tail: .asciz "\033[32mo\033[0m"				// green 0
border: .asciz "\033[33m#\033[0m"			// yellow #
bug1: .asciz "\033[38;5;199m\244\033[0m"	// pink currency sign
bug2: .asciz "\033[38;5;207m~\033[0m"		// pink ~
bug3: .asciz "\033[38;5;165m\272\033[0m"	// pink circle

map: .skip 600  			// allocate space for map: mapxlen * mapylen * 4 bytes per cell, with some extra space

endl: .asciz "\n"

max_len: .word 0			// snake length: 0

.equ MAPXLEN, 14			// define map width as 14 cells
.equ MAPYLEN, 8				// define map height as 8 cells

.text
.global _start

_start:
    bl raw_mode
 
    // Clear screen and hide cursor
    ldr x0, =clear_screen
    bl output
    ldr x0, =hide_cursor
    bl output

    // Print test message
    ldr x0, =test_msg
    bl output

    bl initialize_map

    bl update_and_print_map

    // Wait for keypress
    mov x0, #0              // stdin
    adr x1, input_buffer    // buffer
    mov x2, #1              // count
    mov x8, #63             // read is 63 in 64, 3 in 32
    svc #0

    bl cooked_mode
    // Restore terminal settings
    // mov x0, #0              // stdin
    // movz x1, #0x5402        // TCSETS
    // adr x2, saved_termios
    // mov x8, #29             // ioctl
    // svc #0

    // Show cursor
    ldr x0, =show_cursor
    bl output

    // Exit
    mov x0, #0              // status
    mov x8, #93             // exit
    svc #0


initialize_map:
	stp x4, lr, [sp, #-16]!

	//horizontal borders//
	ldr x4, =map
	mov x0, #0
	mov x1, #MAPYLEN
	sub x2, x1, #1		// compute offset for bottom row
	mov x1, #MAPXLEN
	mul x2, x2, x1
	mov x1, #4
	mul x2, x2, x1
top_loop:
        cmp x0, #MAPXLEN
        beq end_top_loop
        add x0, x0, #1

	mov x1, #-1
	str x1, [x4]
	str x1, [x4, x2]  	// r2 is the offset for bottom row
	add x4, x4, #4
	b top_loop
end_top_loop:
	//vertical borders//
	ldr x4, =map
	mov x0, #0
        mov x1, #MAPXLEN
        sub x2, x1, #1          // compute offset for left row
	mov x3, #4
	mul x2, x2, x3
        mov x1, #MAPXLEN
        mul x3, x1, x3
side_loop:
	cmp x0, #MAPYLEN
	beq end_side_loop
        add x0, x0, #1

        mov x1, #-1
        str x1, [x4]
        str x1, [x4, x2]  	// r2 is offset for left row
        add x4, x4, x3   	// r3 is offset for next point
        b side_loop
end_side_loop:
	// currently it seems like all squares are initializing to -1 - can fix the underlying problem once we can see it
	// bl add_new_bug
	ldp x4, lr, [sp], #16
	ret lr

update_and_print_map:
	stp x4, x5, [sp, #-16]!
	stp x6, x7, [sp, #-16]!
	stp x8, lr, [sp, #-16]!
	ldr x6, =map
        ldr x0, =clear_screen
        bl output

        mov x5, #0
mapy_loop:
        mov x4, #0
        cmp x5, #MAPYLEN
        beq end_map_loop
        add x5, x5, #1
	ldr x0, =space
	bl output
mapx_loop:
	cmp x4, #MAPXLEN
	beq line_break_and_output
	beq mapy_loop
	add x4, x4, #1

	//// Update and print map point ////
	ldr x8, [x6]            // load map point

	ldr x7, =empty
	cmp x8, #0              //if point is:
	csel x0, x7, x0, eq     //==0 --> '.' to be printed
	// bgt snake_tail_age
		

	ldr x7, =snake        //==1 --> '@' head
	cmp x8, #1
    csel x0, x7, x0, eq
	ldr x7, =tail         //>1 --> '0' tail
	// cmp x8, #1
	csel x0, x7, x0, gt

    ldr x7, =border       //==-1 --> '#'
	cmp x8, #-1
	csel x0, x7, x0, eq

	ldr x7, =bug1
	cmp x8, #-2             //==-2 --> '*'
	csel x0, x7, x0, eq

    ldr x7, =bug2
	cmp x8, #-3             //==-3 --> '~'
	csel x0, x7, x0, eq

    ldr x7, =bug3
	cmp x8, #-4             //==-4 --> '%'
    csel x0, x7, x0, eq

	ldr x1, =max_len        // cut tail if its too long
	ldr x1, [x1]
	add x1, x1, #1
	cmp x8, x1
	// bgt reset_point_empty

	bl output               // print the point

	add x6, x6, #4          // next  point in map
	b mapx_loop
snake_tail_age:
	add x0, x8, #1
	str x0, [x6]
	ret
reset_point_empty:
	mov x0, #0
	str x0, [x6]
	ldr x0, =empty
	ret
line_break_and_output:
	ldr x0, =endl
	bl output
	b mapx_loop
end_map_loop:
	ldr x0, =endl
	bl output
	ldp x8, lr, [sp], #16
	ldp x6, x7, [sp], #16
	ldp x4, x5, [sp], #16
	ret

output:
	stp x4, x6, [sp, #-16]!
	stp x7, lr, [sp, #-16]!

	mov x4, x0		// store orig addr of string
	mov x3, #0
count_loop:			// count chars in the string
	ldrb w1, [x0], #1	// each char is one byte
	cbz w1, next_print	// each string must be null-ended
	// this shouldn't be run if equal
	add x3, x3, #1
	b count_loop
next_print:
	mov x0, #1              // stdout
	mov x1, x4
	mov x2, x3
	mov x8, #64              // syscall for 'write'
	svc #0                  // software interrupt

	ldp x7, lr, [sp], #16
	ldp x4, x6, [sp], #16
	ret

raw_mode:
	stp x4, x5, [sp, #-16]!
	stp x6, x7, [sp, #-16]!
	stp x8, lr, [sp, #-16]!

	bl save_termios
	
    // numbers are defined in /usr/include/asm-generic/termbits.h
	//termattr.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	mov x1, #1000	        // ECHO - Echo input characters
	// mov x1, #0x00008		// ECHO - Echo input characters
	orr x1, x1, #2	        // ICANON - Enable canonical mode
	// orr x1, x1, #0x00002	// ICANON - Enable canonical mode
	orr x1, x1, #0x08000    // IEXTEN - Enable implementation-defined input processing
	// orr x1, x1, #0x08000	// IEXTEN - Enable implementation-defined input processing
	orr x1, x1, #01		    // ISIG - Generate INTR, QUIT, SUSP, DSUSP when received
	// orr x1, x1, #0x0001		// ISIG - Generate INTR, QUIT, SUSP, DSUSP when received
	mvn x1, x1				// Negate all above bits
	ldr x6, [x0, #+12]		// Load in c_lflag
	and x6, x6, x1			// Negate the flags we specified
	str x6, [x0, #+12]		// Store modified value in termios
   	//termattr.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	mov x2, #2              // BRKINT - Negating ignores BREAK signals or reads as null byte
	orr x2, x2, #0x400      // ICRNL - Translate carriage return to newline on input
	orr x2, x2, #0x20       // INPCK - Enable input parity checking
	orr x2, x2, #0x2000     // ISTRIP - Strip off eighth bit
	mvn x2, x2              // negate this to turn the flags off
	ldr x6, [x0]
        and x6, x6, x2
        str x6, [x0]
  	//termattr.c_cflag &= ~(CSIZE | PARENB);
	mov x3, #0x3F
	orr x3, x3, #0x100
	mvn x3, x3
	ldr x6, [x0, #+8]
        and x6, x6, x3
   	//termattr.c_cflag |= CS8;
	mov x4, #0x30
        orr x6, x6, x4
        str x6, [x0, #+8]
   	//termattr.c_oflag &= ~(OPOST);
	// movn x5, #1
 	// ldr x6, [x0, #+4]
    // and x6, x6, x5
    // str x6, [x0, #+4]
	//termattr.c_cc[VMIN] = 1;  // or 0 for some Unices 
   	// mov x7, #0		// needs to be 0 for Raspbian
	// strb w7, [x0, #+23]	// 16 + 1 + 6 (VMIN) 
	//termattr.c_cc[VTIME] = 0;
	mov x8, #0
	strb w8, [x0, #+22]	// 16 + 1 + 5 (VTIME)

	bl write_termios

	ldp x8, lr, [sp], #16
	ldp x6, x7, [sp], #16
	ldp x4, x5, [sp], #16

	ret

save_termios:
	stp x4, lr, [sp, #-16]!
    bl read_termios
    ldr x0, =termios
    ldr x1, =saved_termios
	
	// janky but confirmed to work - replace with a loop later?
    ldp x2, x3, [x0]
    stp x2, x3, [x1]
    ldp x2, x3, [x0, #16]
    stp x2, x3, [x1, #16]
    ldp x2, x3, [x0, #32]
    stp x2, x3, [x1, #32]
    // mov x2, #0
// loop_save:                      // save old configurations
    // cmp x2, #11
    // beq end_loop_save
    // ldr x3, [x0], #4
    // str x3, [x1], #4
    // add x1, x1, #1
    // b loop_save
// end_loop_save:
	ldp x4, lr, [sp], #16
	ret
write_termios:
	stp x8, lr, [sp, #-16]!

    mov x0, #0              // stdin
    movz x1, #0x5402        // WRITE termios parameters
    adr x2, termios        // address for termios buffer
    mov x8, #29             // syscall for ioctl 0x36
    svc #0

	ldp x8, lr, [sp], #16
        ret

read_termios:
	stp x8, lr, [sp, #-16]!
	mov x0,	#0		// stdin
	movz x1, #0x5401 	// READ termios parameters
	ldr x2, =termios	// address for termios buffer
	mov x8, #29		// syscall for ioctl 0x36
	svc #0

	ldp x8, lr, [sp], #16
    ret

cooked_mode:
	stp x4, lr, [sp, #-16]!
	ldr x0, =termios
        mov x1, #0
        ldr x2, =saved_termios
loop_load:                      // load old configurations
        cmp x1, #11
        beq end_loop_load
        ldr x3, [x2], #4
        str x3, [x0], #4
        add x1, x1, #1
	b loop_load
end_loop_load:
	bl write_termios
	ldp x4, lr, [sp], #16
	ret

