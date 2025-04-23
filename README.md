# README

## How to Run

1) Clone the repository to your Raspberry Pi. This has been tested on a Raspberry Pi 3 Model B V1.2; it is not guaranteed to work on other machines and is confirmed not to work on Apple AARCH64 machines.
2) Make sure the `as` and `ld` commands are available.
3) Run the following commands to compile:

```
as -o snake.o snake.s
ld -o snake snake.o
```

4) Run the following command to run the snake game:
```
./snake
```

## How it Works

The program will run directly from your terminal - no need for a separate graphics program! It temporarily switches off a few settings in the terminal window in order to receive input directly from the user. Use the WASD keys to change direction!

The game stores all its information in a piece of memory called the map. A reference to the first address is stored globally, and each cell is represented internally by 64 bits. The memory associated with a border cell holds a value of `-1`, while the bugs/fruit that appear for the snake to eat are marked by lower negative numbers. The snake's head is represented by a value of `1`, and the cells belonging to the tail store the distance from the head. (For example, if the snake is composed of a head and three tail pieces, the cell belonging to the very end piece would hold a `4` in memory.) This allows the game to very easily determine where on the board the tail should appear; each time the head moves by one cell, each cell in the tail gets a bit farther away. When a cell's distance is further than the max length allowed, it becomes an empty cell once again. (Empty cells are stored as `0`.)

## Course Concepts Applied

As far as I can tell, my Raspberry Pi cannot run ARM32 assembly code - only ARM64. Although I couldn't find anything labeled as an ARM64 Snake Game starter kit, I did find [this](https://github.com/haperofi/asm_snake/blob/main/mato.s) implemented Snake game. At least, as far as I could tell, it had been fully implemented; it's written in ARM32. I thought it would be a great challenge and test of my understanding if I updated it to run in ARM64! It also marks a huge improvement to the program itself as this allows a ton of machines to run it that otherwise would not have been able to.

One of the first issues I ran into was the fact that the commands for interacting with the stack in ARM32 had been deprecated. The ARM64 version is much more hands-on - rather than using a simple `push` method on as many registers as you want, ARM64 requires you to use the stack pointer to store and load stack data, and it's up to you to offset the pointer every time. This forced me to think much harder about the mechanics of the stack, especially since the operations felt backwards in my mind! I'm used to thinking of a stack as having the oldest items at the bottom and the newest near the top where they're accessible, but the Assembly stack expands from the top down. I kept mixing up which operations needed a positive vs. negative offset. And I had to think more carefully about the order I placed things in the stack! In one part of the code, six of the registers are added to the stack and loaded back out at the end of the function, one of which was the link register. When I first tested this code, I kept getting segmentation faults, and I was unsure why they were happening - until I realized that I had attempted to pop the data in the same order I'd pushed it. Because of this, the address that I'd pushed from the link register was being loaded into register 5 and vice versa - and register 5 was occasionally empty when that function ran. 

Another early problem was ARM64's differing approach to conditionals. In ARM32, nearly any command can be modified with a condition operator, which restricts the command to only run when that condition is met. This seemed very simple and easy to me, but unfortunately it was not an option in ARM64. Instead, the preferred approach is to use branches, which I was much less comfortable with going into this project. Earlier on in the project, I found myself trying to stay as close as possible to the original ARM32 code, but as I grew more comfortable with the language and the flow of the program, I began to realize that many of the functions actually made much more sense in a branched structure.

Another key difference can be found in naming conventions for the registers. Initially I thought this would be an easy switch - that I could just rename any references to a register from `r#` to `x#`. The first problem I ran into with that idea had to do with system calls - which, incidentally, I had also thought might be easy enough to translate! While ARM32 uses the contents of register 7 to determine which system call to make, ARM64 uses register 8. ARM64 also uses a completely different numbering system for its system calls. For example, to make a `write` call in ARM32, you would store `4` in `r7`, while in ARM64, you would store `64` in `x8`.

Later on, the difference between types of registers caused another problem as I found a strange bug in my game map. The cells next to the left border were displaying as snake tails, despite the fact that no tail had been formed. As I worked to understand why this bug was happening, I became very comfortable with my debugger, `gdb`. It allowed me to walk through the map initialization function and look through the values stored in both the map and my registers. (Though it sure took awhile to figure out its syntax!) This allowed me to pin down the exact line at which unexpected behavior occurred, and finally I discovered that it was happening because of the size difference between registers in ARM32 and ARM64. All registers in ARM32 hold 32 bits, but ARM64 registers can hold either 32 or 64 bits. Originally, the cells of my map also held 32 bits as well, which meant that the bits from the border cells were filling more space than I'd realized. When I'd iterated over the border cells, I'd been adding filling more space than I moved my pointer, so each cell's data spilled into the next and caused a mess. To fix this, I briefly looked into using the variants of `ldr` and `str` that limit the size of the data transfer. Unfortunately, for some reason, `str w#` still stored the full double-word on my machine, and `strh` would have been more hassle than it was worth - but in looking into this option, I gained a much better understanding of ARM64's ability to store different amounts of data!

I also ran into several issues that were caused more by my particular system than anything. In order to accept input in real time, without needing to press Enter after every command, the game has to contact the terminal directly and change some settings. Each of these settings were bound to a specific flag at a certain address, and many of them differed between my machine and the one used by the author of the ARM32 version. I'm unsure how much variation exists among other devices, but I dug through my system and found exactly where that information is stored on my Raspberry Pi - so I'm hopeful I could load the game onto another similar device if the need arose!

After finishing this project, I feel much more confident in my understanding of how programs like my snake game work at a low level. Though I felt like a fish out of water at first, with even capabilities like `print` requiring significant effort, I found it extremely satisfying to watch the game come together. I'd periodically notice commands we had built for assignments and realize I understood how that part of the code worked down to the circuitry itself. Even though it isn't the most practical language, I sort of wish I had more reason to use it!
