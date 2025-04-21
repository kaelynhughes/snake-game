.data
clear_screen: .asciz "\033[2J\n"
hide_cursor: .asciz "\033[?25l"
show_cursor: .asciz "\033[?25h"
test_msg: .asciz "test\n"
termios: .skip 100
saved_termios: .skip 100
input_buffer: .skip 1

.text
.global _start

_start:
    // Set up stack
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl raw_mode

    // Clear screen and hide cursor
    ldr x0, =clear_screen
    bl output
    ldr x0, =hide_cursor
    bl output

    // Print test message
    ldr x0, =test_msg
    bl output

    // Wait for keypress
    mov x0, #0              // stdin
    adr x1, input_buffer    // buffer
    mov x2, #1              // count
    mov x8, #63             // read is 63 in 64, 3 in 32
    svc #0

    // Restore terminal settings
    mov x0, #0              // stdin
    movz x1, #0x5402        // TCSETS
    adr x2, saved_termios
    mov x8, #29             // ioctl
    svc #0

    // Show cursor
    ldr x0, =show_cursor
    bl output

    // Exit
    mov x0, #0              // status
    mov x8, #93             // exit
    svc #0

output:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Count string length
    mov x1, x0
    mov x2, #0
count_loop:
    ldrb w3, [x0], #1
    cbz w3, print
    add x2, x2, #1
    b count_loop

print:
    mov x0, #1              // stdout
    mov x8, #64             // write is 64 in 64, 4 in 32
    svc #0

    ldp x29, x30, [sp], #16
    ret 

raw_mode:
	stp x4, x5, [sp, #-16]!
	stp x6, x7, [sp, #-16]!
	stp x8, lr, [sp, #-16]!

    mov x7, #0

	bl save_termios
	//termattr.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	mov x1, #1000			// ECHO flag
	orr x1, x1, #2			// ICANON flag
	orr x1, x1, #0100000	// IEXTEN flag
	orr x1, x1, #01			// ISIG flag
	mvn x1, x1				// negate this to create a mask for clearing bits
	ldr x6, [x0, #+12]		// load the current flag
	and x6, x6, x1			// negate the flags we don't want
	str x6, [x0, #+12]		// store modified value
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

    mov     x0, #1              // stdout
	ldr     x1, =test_msg       // address of message
	mov     x2, #5              // message length
	mov     x8, #64             // syscall: write
	svc     #0

	ldp x4, x5, [sp], #16
	ldp x6, x7, [sp], #16
	ldp x8, lr, [sp], #16

    mov     x0, #1              // stdout
	ldr     x1, =test_msg       // address of message
	mov     x2, #5              // message length
	mov     x8, #64             // syscall: write
	svc     #0

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
        ldr x2, =termios        // address for termios buffer
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
