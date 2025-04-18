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


SYSCALLS

| ARM32 | ARM64 | Name              |
| ----- | ----- | ----------------- |
| 0     | 128   | restart_syscall   |
| 1     | 93    | exit              |
