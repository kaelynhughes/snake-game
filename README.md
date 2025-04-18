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


SYSCALLS

| ARM32 | ARM64 | Name              |
| ----- | ----- | ----------------- |
| 0     | 128   | restart_syscall   |
