.data
clear_screen: .asciz "\nclear screen\n"
hide_cursor: .asciz "\nhide cursor\n"
show_cursor: .asciz "\nshow cursor\n"
test_msg: .asciz "Terminal test - press any key to continue\n"
debug_msg: .asciz "Debug: Before clear screen\n"
debug_msg2: .asciz "Debug: After clear screen\n"
termios: .skip 100
saved_termios: .skip 100
input_buffer: .skip 1

.text
.global _start

_start:
    // Set up stack
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Print debug message before any terminal changes
    ldr x0, =debug_msg
    bl output

    // Save current terminal settings
    mov x0, #0              // stdin
    movz x1, #0x5401        // TCGETS
    adr x2, termios
    mov x8, #29             // ioctl is 29 in 64, 54 in 32
    svc #0

    // Copy to saved settings
    adr x0, termios
    adr x1, saved_termios
    ldp x2, x3, [x0]
    stp x2, x3, [x1]
    ldp x2, x3, [x0, #16]
    stp x2, x3, [x1, #16]
    ldp x2, x3, [x0, #32]
    stp x2, x3, [x1, #32]

    // Set raw mode
    adr x0, termios
    ldr x1, [x0, #12]       // c_lflag
    mov x2, #0x00000002     // ICANON
    mvn x2, x2
    and x1, x1, x2
    mov x2, #1000           // ECHO
    mvn x2, x2
    and x1, x1, x2
    str x1, [x0, #12]

    // Apply new settings
    mov x0, #0              // stdin
    movz x1, #0x5402        // TCSETS
    adr x2, termios
    mov x8, #29             // ioctl
    svc #0

    // Clear screen and hide cursor
    adr x0, clear_screen
    bl output
    adr x0, hide_cursor
    bl output

    // Print test message
    adr x0, test_msg
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
    adr x0, show_cursor
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
    ldrb w3, [x1], #1
    cbz w3, print
    add x2, x2, #1
    b count_loop

print:
    mov x0, #1              // stdout
    mov x8, #64             // write is 64 in 64, 4 in 32
    svc #0

    ldp x29, x30, [sp], #16
    ret 
