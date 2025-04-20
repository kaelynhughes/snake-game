.data

.align 4
space: .asciz "   "
empty: .asciz "\033[38;5;130m.\033[0m"	// brown .
snake: .asciz "\033[32m@\033[0m"	// green @
tail: .asciz "\033[32mo\033[0m"		// green 0
border: .asciz "\033[33m#\033[0m"	// yellow #
bug1: .asciz "\033[38;5;199m\244\033[0m"// pink currency sing
bug2: .asciz "\033[38;5;207m~\033[0m"	// pink ~
bug3: .asciz "\033[38;5;165m\272\033[0m"// pink circle
clear_screen: .asciz "\033[2J\n"
move_up: .asciz "\033[1A"
hide_cursor: .asciz "\033[?25l"
show_cursor: .asciz "\033[?25h"
endl: .asciz "\n"
game_over: .asciz "\033[1A Game Over. Score: "
.align 4
msg:    .asciz "X"
msg2:	.asciz "x"
map: .skip 600  		// mapxlen*mapylen*4
dx: .word 1			// snake directions
dy: .word 0
headx: .word 3			// snake head coords
heady: .word 3
max_len: .word 0		// snake length
random_seed: .word 0x1234	// updated from gettimeofday
rw_buffer: .skip 100
termios: .skip 100		// terminal input configs
saved_termios: .skip 100
delay_ticks: .word 800000000	// game speed for Samsung S10 -- for Raspberry Pi 3, use 230000000
.equ MAPXLEN, 14
.equ MAPYLEN, 8

.text
.global _start

///////////////////////////////////////////////
///////////////////  MAIN  ////////////////////
///////////////////////////////////////////////
_start:
	stp x4, lr, [sp, #-16]!

	bl save_termios
	bl init_random_seed
	bl initialize_map
	mov     x0, #1              // stdout
	ldr     x1, =msg            // address of message
	mov     x2, #1              // message length
	mov     x8, #64             // syscall: write
	svc     #0

        ldr x0, =hide_cursor
        bl output

game_loop:

	bl move_and_check_collision	// update snake position
	cmp x0, #1			// did collision occur?
	beq the_end

	bl update_and_print_map

	bl check_keypress		// check if key was pressed
					// update dx and dy if needed
	b game_loop			// loop until collision

the_end:
	ldr x0, =game_over
	bl output
	ldr x0, =max_len
	ldr x0, [x0]
	bl output_int
	ldr x0, =endl
	bl output

	bl kbhit		// wait for any key
	bl cooked_mode		// just to be sure, restore termios

        ldr x0, =endl
        bl output
	ldr x0, =show_cursor
	bl output
	ldp x4, lr, [sp], #16
	
	mov x0, #0		// exit status 0 (ok)
    	mov x7, #93		// syscall 1 (exit) is 93 in ARM64
    	svc #0

///////////////////////////////////////////////////
/////////////// END MAIN //////////////////////////
///////////////////////////////////////////////////




/////// MOVE AND CHECK SNAKE COLLISION ///////////
// Input: none
// Output: r0, =1 fatal collision, =0 no fatal collision
// Updates headx, heady. If collides with bug, increase max_len
// and go add a new bug
move_and_check_collision:
	stp x4, x5, [sp, #-16]!
	stp x6, x7, [sp, #-16]!
	stp x8, lr, [sp, #-16]!
	ldr x4, =map

        ldr x1, =headx
        ldr x1, [x1]
        ldr x0, =dx
        ldr x0, [x0]
        add x5, x1, x0		// r5 = headx + dx
        ldr x2, =heady
        ldr x2, [x2]
        ldr x0, =dy
        ldr x0, [x0]
        add x6, x2, x0		// r6 = heady + dy
        mov x0, #MAPXLEN	// get map address for head (r3)
        mul x3, x6, x0
        add x3, x3, x5
        mov x0, #4
        mul x7, x3, x0		// (head) r7 = y*mapxlen + x

        ldr x0, [x4, x7]	// r0 = map point for next step
        cmp x0, #0              // collision to points >0 --> end
        bgt collision

        cmp x0, #-1             // -"- ==-1 --> end
        beq collision
		blt bug_collision

        mov x0, #1		// store new head point to map
        str x0, [x4, x7]
        ldr x0, =headx
        str x5, [x0] 		// store new headx
        ldr x0, =heady
        str x6, [x0]    	// store new heady

	mov x0, #0
	b end_move_and_coll
bug_collision:
	adrp x1, max_len
	add x1, x1, :lo12:max_len
	ldr x0, [x1]
	add x0, x0, #1
	str x0, [x1]
	b add_new_bug
collision:
	mov x0, #1
end_move_and_coll:
	ldp x4, x5, [sp], #16
	ldp x6, x7, [sp], #16
	ldp x8, lr, [sp], #16
	ret
///////////////////////////////////////////////


/////// PRINT AND UPDATE MAP ///////////////////
// Input: none
// Output: none, updates and prints map
// Map is the main data structure for the game. Snake
// head is 0 ('@'), tail is increasing numbers 1,2,3,.. ('O').
// At each update step, tail is aged, and based on max_len,
// an empty space may be drawn instead: 0 ('.'). Borders
// are -1 ('#'). Different bugs are -2, -3, -4.
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
		beq mapy_loop
        beq line_break_and_output
        add x4, x4, #1

        //// Update and print map point ////
        ldr x7, [x6]            // load map point

        cmp x7, #0              //if point is:
		beq snake_tail_age
		ldr x8, =empty
        csel x0, x8, x0, eq     //==0 --> '.' to be printed
        cmp x7, #1
        ldr x8, =snake        //==1 --> '@' head
        csel x0, x8, x0, eq
        ldr x8, =tail         //>1 --> '0' tail
        csel x0, x8, x0, gt
        cmp x7, #-1
        ldr x8, =border       //==-1 --> '#'
        csel x0, x8, x0, eq
        cmp x7, #-2             //==-2 --> '*'
        ldr x8, =bug1
        csel x0, x8, x0, eq
	cmp x7, #-3             //==-3 --> '~'
        ldr x8, =bug2
        csel x0, x8, x0, eq
	cmp x7, #-4             //==-4 --> '%'
        ldr x8, =bug3
        csel x0, x8, x0, eq


        ldr x1, =max_len        // cut tail if its too long
        ldr x1, [x1]
        add x1, x1, #1
        cmp x7, x1
		bgt reset_point_empty

        bl output               // print the point

        add x6, x6, #4          // next  point in map
        b mapx_loop
snake_tail_age:
	add x0, x7, #1
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
	ldp x4, x5, [sp], #16
	ldp x6, x7, [sp], #16
	ldp x8, lr, [sp], #16
	ret
///////////////////////////////////////////////



/////////// CHECK KEYPRESS and UPDATE DX DY ///
// Input: none
// Output: none, update dx and dy
check_keypress:
	stp x4, x5, [sp, #-16]!
	stp x6, lr, [sp, #-16]!

      	bl raw_mode		// key presses are not buffered
      	bl delay
      	bl input
	ldr x4, [x0]
      	bl cooked_mode		// return to normal mode immediately
				// this is overkill, but helps when
				// debugging

      	//bl initscr            // For A LOT easier implementation,
        //bl noecho             // one could use ncurses C-library
        //bl cbreak             //
        //mov r0, #500          // wait 500ms for keypress
        //bl timeout            //
        //bl getch              // ncurses function: get non-blocking
 	//mov r4, r0            // keypress, store in r0
	//bl endwin		//

	mov x1, #1
	cmp x4, #0x73           // 'w'
	csel x0, x1, x0, eq
        beq update_dxdy

	mov x1, #2
        cmp x4, #0x61           // 'a'
	csel x0, x1, x0, eq
        beq update_dxdy

	mov x1, #3
        cmp x4, #0x77           // 's'
	csel x0, x1, x0, eq
        beq update_dxdy

	mov x1, #4
        cmp x4, #0x64           // 'd'
	csel x0, x1, x0, eq
        beq update_dxdy

	b end_check_keypress

update_dxdy:
	ldr x1, =dx
	ldr x2, =dy

	mov x4, #0	// new dx
	mov x5, #0	// new dy

	mov x3, #1

	cmp x0, #1
	csel x5, x3, x5, eq

        cmp x0, #4
	csel x4, x3, x4, eq

	mov x3, #-1

        cmp x0, #2
	csel x4, x3, x4, eq

        cmp x0, #3
	csel x5, x3, x5, eq

	str x4, [x1]
	str x5, [x2]

end_check_keypress:
	ldp x4, x5, [sp], #16
	ldp x6, lr, [sp], #16
	ret
//////////////////////////////////////


////////// INIT MAP /////////////////
// Input: none
// Output: none
// Initialize map values, mainly draw borders.
initialize_map:
	mov     x0, #1              // stdout
	ldr     x1, =msg2            // address of message
	mov     x2, #1              // message length
	mov     x8, #64             // syscall: write
	svc     #0
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
	mov     x0, #1              // stdout
	ldr     x1, =msg            // address of message
	mov     x2, #1              // message length
	mov     x8, #64             // syscall: write
	svc     #0
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

	bl add_new_bug

	ldp x4, lr, [sp], #16
	ret lr
////////////////////////////////


////// ADD NEW BUG /////////////
// Input: none
// Output: none
// Adds a new random bug to the map in a random location
add_new_bug:
	stp x4, x5, [sp, #-16]!
	stp x6, lr, [sp, #-16]!
	ldr x4, =map
        mov x1, #MAPYLEN
        mov x2, #MAPXLEN
        mul x5, x1, x2      // mapylen*mapxlen
	bl get_random			// r0 = next random
	mov x1, #3
	bl divide				// r0 = r0 % 3
	mov x3, #-4
	cmp x0, #0
	csel x6, x3, x6, eq		// new bug '%'
	cmp x0, #1
	cinc x6, x6, eq	        // bug is '~'

	cinc x6, x6, gt			// twice if greater so x6 holds -2
	cinc x6, x6, gt			// bug is '*'

add_bug_new_try:
	bl get_random		// r0 = next random
	mov x1, x5
	bl divide		// r0 / (mapylen*mapxlen)
				// --> r0 stores the modulo
	mov x3, #4
	mul x0, x0, x3  	// map address for new bug

	ldr x3, [x4, x0]	// load map point
	cmp x3, #0			// map point must be empty = 0 = '.'
	csel x2, x6, x2, eq // new bug: -2, -3, or -4
	bne add_bug_new_try	// if not empty, try again

	// this will not be run if not equal
	str x2, [x4, x0]	// store bug to map

	ldp x4, x5, [sp], #16
	ldp x6, lr, [sp], #16
	ret
/////////////////////////////////////


////// DIVISION (integer) ///////////
// Input: r0 (dividend), r1 (divisor), both integers
// Output: r0 (remainder, modulo), r1 (integer result of r0/r1)
divide:
	mov x2, #0
divide_loop:		// how many times r1 can be substr from r0?
	cmp x0, x1
	csel x1, x2, x1, lt
	blt end_divide

	sub x0, x0, x1
	add x2, x2, #1  // increase counter
	b divide_loop

end_divide:
	ret
/////////////////////////////////////


//// NEXT RANDOM (positive) INT  ////
// Input: none
// Output: r0, next random number (positive)
// Takes random_seed from memory, updates the seed and returns it.
// Numbers are 2's complement, so lsr should make every number positive.
// Note that #1 shift would be enough for this purpose, but we want 
// small random numbers so calculating the following modulo is fast
get_random:
	ldr x1, =random_seed
	ldr x0, [x1]
	add x0, x0, #137
	eor x0, x0, x0, ror #13
	lsr x0, x0, #5	//shift right to ensure positiveness
	str x0, [x1]

	ret
/////////////////////////////////////


///////// INIT RANDOM SEED //////////
// Input: none
// Output: none, updates random_seed
// Makes a software interrupt by supervisor call to gettimeofday
// Interrupt numbers from: https://syscalls.w3challs.com/?arch=arm_strong
// For Raspberry Pi, replace 9 in 0x900.. with 0
init_random_seed:
		stp x7, lr, [sp, #-16]!
        ldr x0, =random_seed
        mov x7, #0x00004e	// syscall for gettimeofday
        svc #0

	ldp x7, lr, [sp], #16
        ret
/////////////////////////////////////


////// OUTPUT //////////////////////
// Input: r0, address of string to print
// Output: none, prints to stdout
output:
	stp x4, x6, [sp, #-16]!
	stp x7, lr, [sp, #-16]!
	mov x4, x0		// store orig addr of string
	mov x3, #0
count_loop:			// count chars in the string
	ldrb w1, [x0], #1	// each char is one byte
	cmp x1, #0		// each string must be null-ended
	beq next_print
	// this shouldn't be run if equal
	add x3, x3, #1
	b count_loop
next_print:
	mov x0, #1              // stdout
    	mov x1, x4	        // address of the string
    	mov x2, x3             	// string length
    	mov x7, #4              // syscall for 'write'
    	svc #0                  // software interrupt
	ldp x4, x6, [sp], #16
	ldp x7, lr, [sp], #16
	ret
////////////////////////////////////


////// INPUT ///////////////////////
// Input: none
// Output: address of input string =rw_buffer
input:
	stp x4, x6, [sp, #-16]!
	stp x7, lr, [sp, #-16]!
	ldr x4, =rw_buffer
	mov x1, #0
	str x1, [x4]
	str x1, [x4, #+4]	// make sure buffer is empty

	mov x0, #0              // stdin
        mov x1, x4              // address of the string
        mov x2, #1              // string length = 1
        mov x7, #3              // syscall for 'write'
        svc #0                  // software interrupt

	mov x0, x4		//return address of string

end_input:
	nop
	ldp x4, x6, [sp], #16
	ldp x7, lr, [sp], #16
        ret
////////////////////////////////////////////////


////// OUTPUT INTEGER TO PRINT AS STRING ///////
// Input: r0, 32 bit positive integer
// Output: none, prints r0 to stdout as decimal
output_int:
	stp x4, x5, [sp, #-16]!
	stp x6, lr, [sp, #-16]!
	mov x4, x0
    	mov x5, #8		// word is 8 x 4 bits
	mov x6, #0		// carry
	ldr x3, =rw_buffer	// buffer to write string
	add x3, x3, #7		// start writing from end
output_int_loop:
    	// Take least significant 4 bits from r4 into r0, loop 8 times
    	mov x0, x4, lsl #28
	mov x0, x0, lsr #28

	cmp x6, #0		// add carry if previous round >9
	cinc x0, x0, gt
	csel x6, xzr, x6, gt

	cmp x0, #9		// check if >9, if so mark carry
	mov x8, x0
	sub x8, x8, #10
	csel x0, x8, x0, gt
	mov x8, #1
	csel x6, x8, x6, gt

    	mov x4, x4, lsl #4	// Shift r4 for next time

    	// For each nibble (now in r0) convert to ASCII
    	add x0, x0, #48
	strb w0, [x3], #-1

    	sub x5, x5, #1		// decrease loop counter
	cmp x5, #0
    	bne output_int_loop

	ldr x0, =rw_buffer	// reset to start
	mov x2, #6
output_int_loop3:		// skip leading zeroes (max 7)
	ldrb w1, [x0]
	cmp x1, #0x30		//= "0" in ascii
	cinc x0, x0, eq
	bne output_int_end
	subs x2, x2, #1
	bmi output_int_end	//if last number is also 0, print it
	b output_int_loop3
output_int_end:
	bl output

	ldp x4, x5, [sp], #16
	ldp x6, lr, [sp], #16
	ret
////////////////////////////////////////////


////////DELAY///////////////////////////
// Input, Output: none
// Delay program for delay_ticks loop time
delay:
        ldr x0, =delay_ticks
        ldr x0, [x0]
        mov x1, #0
delay_loop:
        cmp x1, x0
        add x1, x1, #1
        blt delay_loop

        ret
////////////////////////////////////////


///// KBHIT ////////////////////////////
// Input, Output: none
// Wait for any key press
kbhit:
	stp x4, lr, [sp, #-16]!
        bl cbreak_off
        bl input
        bl cooked_mode
	ldp x4, lr, [sp], #16
        ret
////////////////////////////////////////



///////////////////////////////////////////////////////
//        TERMIOS MANIPULATION FUNCTIONS
// Controls how data is buffered and read from keyboard
///////////////////////////////////////////////////////
//struct termios {
//    tcflag_t c_iflag;               // input mode flags
//    tcflag_t c_oflag;               // output mode flags
//    tcflag_t c_cflag;               // control mode flags
//    tcflag_t c_lflag;               // local mode flags
//    cc_t c_line;                    // line discipline
//    cc_t c_cc[NCCS];                // control characters
//};
///////////////////////////////////////////////////////
// Input, Output: none
// Saves current termios (terminal input) configs to memory.
// Needed so that they can be restored after config changes.
save_termios:
	stp x4, lr, [sp, #-16]!
        bl read_termios
        ldr x0, =termios
        mov x1, #0
        ldr x2, =saved_termios
loop_save:                      // save old configurations
        cmp x1, #11
        beq end_loop_save
        ldr x3, [x0], #4
        str x3, [x2], #4
        add x1, x1, #1
        b loop_save
end_loop_save:
	ldp x4, lr, [sp], #16
	ret
//////////////////////////////////////////////
// Input, Output: none
// Change input mode to raw mode. Input is not buffered.
// Needed to immediate reading of data from keypresses.
// Following instructions in:
// https://sourceforge.net/p/hla-stdlib/mailman/hla-stdlib-talk/
//         thread/814462.63171.qm@web65510.mail.ac4.yahoo.com/
// Flag values from:
// https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/
//         linux.git/tree/include/uapi/asm-generic/termbits.h?id=HEAD
raw_mode:
	stp x4, x5, [sp, #-16]!
	stp x6, x7, [sp, #-16]!
	stp x8, lr, [sp, #-16]!

	bl save_termios

	ldr x0, =termios
	//termattr.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	mov x1, #1000
	orr x1, x1, #2
	orr x1, x1, #0100000
	orr x1, x1, #01
	mvn x1, x1
	ldr x6, [x0, #+12]
	and x6, x6, x1
	str x6, [x0, #+12]
   	//termattr.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	mov x2, #2
	orr x2, x2, #0x400
	orr x2, x2, #0x20
	orr x2, x2, #0x2000
	mvn x2, x2
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
	movn x5, #1
 	ldr x6, [x0, #+4]
        and x6, x6, x5
        str x6, [x0, #+4]
	//termattr.c_cc[VMIN] = 1;  // or 0 for some Unices 
   	mov x7, #0		// needs to be 0 for Raspbian
	strb w7, [x0, #+23]	// 16 + 1 + 6 (VMIN) 
	//termattr.c_cc[VTIME] = 0;
	mov x8, #0
	strb w8, [x0, #+22]	// 16 + 1 + 5 (VTIME)

	bl write_termios
	ldp x4, x5, [sp], #16
	ldp x6, x7, [sp], #16
	ldp x8, lr, [sp], #16
	ret
/////////////////////////////////////////
// Input, Output: none
// Set input mode to normal mode. Needs pre-saved termios
// structure saved in save_termios. Make sure to call this
// at the end of program, or your terminal input is toast.
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
/////////////////////////////////////////
// Input, Output: none
// Don't wait for a newline in following inputs
cbreak_off:
	stp x7, lr, [sp, #-16]!
        bl read_termios

        ldr x0, =termios
        ldr x1, [x0, #+12]!
	movn x2, #0x00000002 	// NOT ICANON flag
        and x1, x1, x2		// AND local flag
	movn x2, #1000		// NOT ECHO flag
	and x1, x1, x2		// AND local flag
        str x1, [x0]            // store back to termios+12

        bl write_termios
	ldp x7, lr, [sp], #16
        ret
//////////////////////////////////////////
// Input, Output: none
// Wait for newline to buffer input, as normal
cbreak_on:
	stp x7, lr, [sp, #-16]!
        bl read_termios

	ldr x0, =termios
	ldr x1, [x0, #+12]!
	mov x2, #0x00000002	// ICANON flag
	orr x1, x1, x2		// canonical bit ON in local mode flags
        mov x2, #1000           // ECHO flag
        and x1, x1, x2
	str x1, [x0]		// store back to termios+12

        bl write_termios
	ldp x7, lr, [sp], #16
	ret
//////////////////////////////////////////
// Input, Output: none
// Make syscall to ioctl and read termios structure to memory
read_termios:
	stp x7, lr, [sp, #-16]!

	mov x0,	#0		// stdin
	movz x1, #0x5401 	// READ termios parameters
	ldr x2, =termios	// address for termios buffer
	mov x7, #54		// syscall for ioctl 0x36
	svc #0

	ldp x7, lr, [sp], #16
        ret
/////////////////////////////////////////
// Input, Output: none
// Make syscall to ioctl and input termios structure to system
write_termios:
	stp x7, lr, [sp, #-16]!

        mov x0, #0              // stdin
        movz x1, #0x5402        // WRITE termios parameters
        ldr x2, =termios        // address for termios buffer
        mov x7, #54             // syscall for ioctl 0x36
        svc #0

	ldp x7, lr, [sp], #16
        ret
//////////////////////////////////////////
