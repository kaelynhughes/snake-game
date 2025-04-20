.data

.align 4
msg:    .asciz "X"
msg2:	.asciz "O"
// set characters
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

// initialize snake variables
.align 4
map: .skip 600  			// allocate space for map: mapxlen * mapylen * 4 bytes per cell, with some extra space
dx: .word 1					// snake directions - initialize to moving right & not moving vertically
dy: .word 0	
headx: .word 3				// snake head coords - (3, 3)
heady: .word 3
max_len: .word 0			// snake length: 0

// define some globals for gameplay
random_seed: .word 0x1234	// used to generate random bug positions; will be updated using gettimeofday to make it more random
rw_buffer: .skip 100		// allocates 100 bytes for a read/write buffer
termios: .skip 100			// allocates 100 bytes for terminal input configs
saved_termios: .skip 100	// allocates 100 bytes for terminal config backups, so we can restore original state later
delay_ticks: .word 230000000	// game speed for Raspberry Pi 3 -- for Samsung S10, use 800000000
.equ MAPXLEN, 14			// define map width as 14 cells
.equ MAPYLEN, 8				// define map height as 8 cells

.text
.global _start

_start: