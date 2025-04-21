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

    // Print test message
    ldr x0, =test_msg
    bl output

    // Print test message
    ldr x0, =test_msg
    bl output

    // Restore terminal settings
    mov x0, #0              // stdin
    movz x1, #0x5402        // TCSETS
    adr x2, saved_termios
    mov x8, #29             // ioctl
    svc #0

    // Print test message
    ldr x0, =test_msg
    bl output
    // Show cursor
    ldr x0, =show_cursor
    bl output

    // Print test message
    ldr x0, =test_msg
    bl output
    // Print test message
    ldr x0, =test_msg
    bl output
    // Print test message
    ldr x0, =test_msg
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
	movn x5, #1
 	ldr x6, [x0, #+4]
    and x6, x6, x5
    str x6, [x0, #+4]
	//termattr.c_cc[VMIN] = 1;  // or 0 for some Unices 
   	mov x7, #0		// needs to be 0 for Raspbian
	strb w7, [x0, #+23]	// 16 + 1 + 6 (VMIN) 
	//termattr.c_cc[VTIME] = 0;
	// mov x8, #0
	// strb w8, [x0, #+22]	// 16 + 1 + 5 (VTIME)

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

