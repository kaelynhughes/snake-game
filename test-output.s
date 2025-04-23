.data

.align 4
rw_buffer: .skip 100

.text
.global _start


_start:
    mov x0, #1
    bl output_int

    mov x0, #2
    bl output_int

    mov x0, #3
    bl output_int

    mov x0, #4
    bl output_int

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

output_int:
    stp x4, x5, [sp, #-16]!
    stp x6, lr, [sp, #-16]!
    mov x4, x0
    mov x5, #8              // word is 8 x 4 bits
    mov x6, #0              // carry
    ldr x3, =rw_buffer     // buffer to write string
    add x3, x3, #7         // start writing from end
output_int_loop:
    // Take least significant 4 bits from r4 into r0, loop 8 times
    mov x0, x4, lsl #28
    mov x0, x0, lsr #28

    cmp x6, #0             // add carry if previous round >9
    cinc x0, x0, gt
    csel x6, xzr, x6, gt

    cmp x0, #9             // check if >9, if so mark carry
    mov x8, x0
    sub x8, x8, #10
    csel x0, x8, x0, gt
    mov x8, #1
    csel x6, x8, x6, gt

    mov x4, x4, lsl #4     // Shift r4 for next time

    // For each nibble (now in r0) convert to ASCII
    add x0, x0, #48
    strb w0, [x3], #-1

    sub x5, x5, #1         // decrease loop counter
    cmp x5, #0
    bne output_int_loop

    ldr x0, =rw_buffer     // reset to start
    mov x2, #6
output_int_loop3:          // skip leading zeroes (max 7)
    ldrb w1, [x0]
    cmp x1, #0x30          //= "0" in ascii
    cinc x0, x0, eq
    bne output_int_end
    subs x2, x2, #1
    bmi output_int_end     //if last number is also 0, print it
    b output_int_loop3
output_int_end:
    bl output

    ldp x6, lr, [sp], #16
    ldp x4, x5, [sp], #16
    ret
