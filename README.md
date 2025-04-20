# README

## notes

1. trying the .s [file](https://github.com/ahmedshabib/Snake-Game-ARM/blob/master/snake.s) i was looking at originally
    - first problem: this is built for a specific compiler that will not run well on pi
    - can't use SWI calls
    - can't use the flat memory access things bc they may not map well
2. there's a snake-asm [repo](https://github.com/NikitaIvanovV/snake-asm) for x86_64 - might be helpful later?
3. 

## things i've had to do

- the code i found was in ARM32 rather than ARM64 so i'm translating it
- found out there are two different styles of ARM32 programming and my couple sources were using different styles
    - `mov r7, #1` vs `mov %r7, $1`
    - "immediate" operand can be either # or $
- later, look into alignment - my tutorial thing says 32-bit is usually most efficient on a 4-byte boundary (.align 4) - is there a 64-bit equivalent?
- registers move from being called r# to x#
- `bx lr` (branch exchange link register - returns you to the address you were at before you jumped to a subroutine/function) becomes `ret`
- `push` becomes `stp` or `str` for storing data in the stack
- `pop` becomes `ldp`
- registers are different in ARM64 than ARM32 - each register is 64 bytes and marked with x, but you can also use the lower half and call it w; the top 32 bits are zeroed out
- you have to be a lot more hands-on with stack operations in arm64 - instead of just using push/pop and it all working out, you have to use the stack pointer and change where it points to
    - 

## potential problems

- check keypress method

## notes

### stp

EXAMPLE:
```
stp x4, x5, [sp, #-16]!
```


SYSCALLS

| ARM32 | ARM64 | Name              |
| ----- | ----- | ----------------- |
| 0     | 128   | restart_syscall   |
| 1     | 93    | exit              |


## map x loop

game_loop -> update_and_print_map
update_and_print_map:
- store registers 4-8 and lr in the stack
- load the map into register 6
- load clear_screen into register 0
- jump to output branch with link

output:
- store registers 4, 6-7, lr in stack
- move contents of register 0 into register 4
- move #0 into register 3
- into count loop:
    - load byte into w1 from register 0
    - compare contents of register 1 with #1
    - if equal, jump to next_print
    - otherwise increment value of x3 by one and branch back to the beginning of the loop
- next_print:
    - move #1 into register 0
    - move contents of register 4 to register 1
    - move contents of register 3 into register 2
    - move 4 into register 7 (syscall for write)
    - software interrupt
    - load stack into registers 4 and 6
    - load stack into register 7 and lr
    - return to spot in the link

back in update_and_print_map:
- move 0 into register 5

map y loop:
- move 0 into register 4
- compare contents of register 5 (set as 0 before first loop) with #MAPYLEN
- end_map_loop if true, otherwise increment register 5 by 1, load space variable into register 0, and do output with link

map x loop:
- compare contents of register 4 with MAPXLEN and if equal, do the map y loop and then line_break_and_input
- add one to register 4
- load the value stored at the address in register 6 (map point) into register 7
- compare that to 0
- if x7 is greater than 0:
    - store one plus the value of register 7 in register 0
    - store the value in register 0 at the address in register 6 (map point)
- if x7 is equal to 0, store the value of empty ('.') in register 0



