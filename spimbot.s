.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c

RIGHT_WALL_SENSOR 	= 0xffff0054
PICK_TREASURE           = 0xffff00e0
TREASURE_MAP            = 0xffff0058
MAZE_MAP                = 0xffff0050

REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8


# struct spim_treasure
#{
#    short x;
#    short y;
#    int points;
#};
#
#struct spim_treasure_map
#{
#    unsigned length;
#    struct spim_treasure treasures[50];
#};
.data
dfs_tree:       .word 0:128                         # puzzle is stored as tree-based array
puzzle_res:     .word 1                             # the solution to the puzzle
puzzle_start:   .word 1                             # boolean flag to tell us when to start requesting puzzles

#Insert whatever static memory you need here

.text
main:
        #Fill in your code here
        li        $t4, TIMER_INT_MASK               # timer interrupt enable bit
        or        $t4, $t4, BONK_INT_MASK           # bonk interrupt bit
        or        $t4, $t4, 1                       # global interrupt enable
        mtc0      $t4, $12                          # set interrupt mask (Status register)
        
        # REQUEST TIMER INTERRUPT 
        # lw      $v0, TIMER($0)                    # read current time
        # jr      $ra                               # ret
        lw        $a1, RIGHT_WALL_SENSOR            # prev right wall
infinite:     
        lw        $a0, RIGHT_WALL_SENSOR            # 1 if wall to right
        bne       $a0, $0, skip_turn    
        beq       $a0, $a1, skip_turn               # rotate 90 if 0
  
        li        $t4, 90
        sw        $t4, ANGLE($0)
        sw        $0,  ANGLE_CONTROL($0)
skip_turn:  
        move      $a1, $a0                          # save prev right wall
        li        $t1, 10    
        sw        $t1, VELOCITY($0)                 # drive
        j         infinite
move_east: # function to move east, to be used when we do actual pathfinding
        li        $t4, 0
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        j         infinite
move_west: # function to move west, to be used when we do actual pathfinding
        li        $t4, 180
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        j         infinite
move_north: # function to move north, to be used when we do actual pathfinding
        li        $t4, 270
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        j         infinite
move_south: # function to move south, to be used when we do actual pathfinding
        li        $t4, 90
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        j         infinite
solve_puzzle: # function to solve a puzzle
        la        $a0, dfs_tree
        li        $a1, 1                        # int i
        li        $a2, 1                        # int input
        jal       _dfs
        sw        $v0, puzzle_res($0)
        la        $t2, puzzle_res
        sw        $t2, SUBMIT_SOLUTION($0)
        j         infinite
req_puzzle: # function to request a puzzle
        la        $t2, dfs_tree
        sw        $t2, REQUEST_PUZZLE($0)
        sw        $0, puzzle_start($0)
        j         infinite
pick_treasure: # function to pick up treasure
        sw        $0, PICK_TREASURE($0)
        j         infinite

# Kernel Text
.kdata
chunkIH:    .space 28
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at                    # Save $at
.set at
        la        $k0, chunkIH         
        sw        $a0, 0($k0)                 # Get some free registers
        sw        $v0, 4($k0)                 # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)

        mfc0      $k0, $13                    # Get Cause register
        srl       $a0, $k0, 2       
        and       $a0, $a0, 0xf               # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch: # Interrupt:
        mfc0      $k0, $13                    # Get Cause register, again
        beq       $k0, 0, done                # handled all outstanding interrupts

        and       $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
        bne       $a0, 0, bonk_interrupt

        and       $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
        bne       $a0, 0, timer_interrupt

        and	  $a0, $k0, REQUEST_PUZZLE_INT_MASK
        bne 	  $a0, 0, request_puzzle_interrupt

        li        $v0, PRINT_STRING           # Unhandled interrupt types
        la        $a0, unhandled_str
        syscall
        j         done

bonk_interrupt: 
        sw        $a1, BONK_ACK($0)           # acknowledge interrupt
        li        $a1, 180                    # turn 180 degrees
        sw        $a1, ANGLE($0)
        sw        $0,  ANGLE_CONTROL($0)
        j         interrupt_dispatch          # see if other interrupts are waiting

request_puzzle_interrupt:
	sw	  $v0, REQUEST_PUZZLE_ACK     # acknowledge interrupt
	j	  interrupt_dispatch	      # see if other interrupts are waiting

timer_interrupt:
        sw        $a1, TIMER_ACK($0)          # acknowledge interrupt
        j         interrupt_dispatch          # see if other interrupts are waiting

non_intrpt: # was some non-interrupt
        li        $v0, PRINT_STRING
        la        $a0, non_intrpt_str
        syscall                               # print out an error message
        # fall through to done

done:
        la        $k0, chunkIH
        lw        $a0, 0($k0)                 # Restore saved registers
        lw        $v0, 4($k0)
	lw        $t0, 8($k0)
        lw        $t1, 12($k0)
        lw        $t2, 16($k0)
        lw        $t3, 20($k0)
.set noat
        move      $at, $k1                    # Restore $at
.set at
        eret