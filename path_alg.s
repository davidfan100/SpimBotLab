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

RIGHT_WALL_SENSOR       = 0xffff0054
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

# struct maze_cell {
#     char s_open;
#     char w_open;
#     char n_open;
#     char e_open;
# };
 
# struct maze_map {
#     maze_cell map[30][30]; // hold the maze map
# };
.data
dfs_tree:       .word 0:128                         # puzzle is stored as tree-based array
puzzle_res:     .word 1                             # the solution to the puzzle
puzzle_start:   .word 1                             # boolean flag to tell us when to start requesting puzzles
treasure_map:   .word 0:404                         # treasure map array, each treasure has x and y location, and point value
maze_map:       .byte 0:3600                        # maze map

# struct costmapcell {
#        int h;         4       heuristic (estimate to curr pos)
#        int g;       4         cost from goal
#}
unexplored:     .byte 0:900                     # array with char (1 = been to, 0 = havent been to)
costmap:        .word 0:7200            
# struct queue {
#        int front; 4
#        int back;  4     
#        int[] queue;            with index as xy unrolled
#}
priority_queue:          .word 0:3608           # queue data struct to be used when pathfinding
update_queue:   .word 0:400                     # queue for when updating (size = 100)
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
        la        $t0, unexplored               # get unexplored address
  #      li        $t2, 1
  #      sb        $t2, 1($t0)                        # initialize as unexplored
  #      lbu        $s7, 1($t0)

        jal         load_treasure_map

 #       li      $t5, 1
        li          $s2, 10                   #  s2 = target x
        li          $s3, 10                     #  s3 = target y
        li      $t1, -1                         # prev direction traveled (1 - came from south)
                                                # (2 - came from west, 3 - came from north, 4 - came from east)

infinite:     
        lw      $s0, BOT_X($0)                  # get x,y coordinates
        div     $s0, $s0, 10                    # s0 = x
        lw      $s1, BOT_Y($0)
        div     $s1, $s1, 10                    # s1 = y

        la      $t0, unexplored
        mul     $t6, $s1, 30
        add     $t6, $t6, $s0                   # getting unexplored index for curr pos
        add     $t6, $t6, $t0
        lbu     $t7, 0($t6)

        bne     $t7, $0, continue               # continue if unexplored == 0
        li      $t0, 1
        sb      $t0, 0($t6)                     # updates unexplored to 1
        j       load_maze_map                   # load updated map since now in unexplored area
continue: # need to implement actually finding cost values

             
        



#         mul     $s4, $s1, 120                    # s4 = array index for maze map
#         mul     $t3, $s0, 4
#         add     $s4, $s4, $t3

#         la      $t4, maze_map
#         add     $t4, $s4, $t4

#         lb      $s4, 0($t4)                     # gets surrounding information from map
#         lb      $s5, 1($t4)
#         lb      $s6, 2($t4)
#         lb      $s7, 3($t4)
# ################# DEBUG ###############
#  #       beq     $s1, $s3, skip_debug            
#         li      $v0, PRINT_INT
#         move    $a0, $s4
#         syscall
#         move    $a0, $s5
#         syscall
#         move    $a0, $s6
#         syscall
#         move    $a0, $s7
#         syscall
#         li      $v0 PRINT_CHAR
#         li      $a0, ' '
#         syscall
#         li      $v0, PRINT_INT
#         move    $a0, $s0
#         syscall
#         move    $a0, $s1
#         syscall
#         li      $v0 PRINT_CHAR
#         li      $a0, '\n'
#         syscall
#         # move    $a0, $t1
#         # syscall


# skip_debug:

# ################# DEBUG ###############

        

        # bne     $s4, $0, move_south
        # bne     $s5, $0, move_west
        # bne     $s7, $0, move_east  
        # bne     $s6, $0, move_north

skip_turn:  

        j infinite
   #     jr      $ra
#######################################
# swaps elements in priority queue
# assumes that first elem is bigger than second elem
# a0 - index of first elem in the array
# a1 - index of second elem in the array
swap:
        sub     $sp, $sp, 24
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $s4, 20($sp)

        la      $s0, queue
        add     $s0, $s0, 8             # s0 - address of the int[] in queue
        mul     $a0, $a0, 4
        add     $s1, $s0, $a0           # s1 - address of first index
        mul     $a1, $a1, 4
        add     $s2, $s0, $a1           # s2 - address of second index
        lw      $s3, 0($s1)             # s3 - data of first index
        lw      $s4, 0($s2)             # s4 - data of second index
        sw      $s4, 0($s1)
        sw      $s3, 0($s2)             # store second data into 

        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        add     $sp, $sp, 24
        jr      $ra

#######################################
# updates costs around given cell
# assumes map does not need to be updated rn
# assume that given cell already has updated cost
# a0 - x coordinate
# a1 - y coordinate
update_costs:
        
        la      $s0, costmap            # s0 - get address of the cost map
        la      $s2, update_queue       # s2 - queue address

        mul     $a1, $a1, 30
        add     $s1, $a1, $a0           # gets unrolled index of curr cell
        mul     $s1, $s1, 8             # mult by 8 because each costcell has 8 bytes
        add     $s1, $s1, $s0           # s1 - current costcell info address

        sw      $s1, 0($s2)             # puts unrolled index of curr costcell into queue
  #      li      $t0, 0                  # t0 - start of queue
        li      $t1, 1                  # t1 - size of queue
        lw      $s7, 0($s1)             #### s7 - h cost to update all surroundings ####
 #       lw      $s3, 4($s1)             # s3 - g cost of curr cell

loop_until_allupdated:
        beq     $t1, $0, update_finished       # return if queue is empty

  #      mul     $t2, $t0, 4                     # gets start address of queue (4 byte int )
  #      add     $t2, $t2, $s2                   # gets start address of queue
        lw      $s1, 0($s2)                     # s1 - curr costcell address (load first elem of queue)
        add     $s2, $s2, 4                     # move address to next element
 #       add     $t0, $t0, 1                     # increment start by one
        sub     $t1, $t1, 1                     # decrement size by one

        sw      $s7, 0($s1)             # update cost
        lw      $s4, 4($s1)             # s5 - g cost of curr cell
        sub     $s5, $s4, 1             # s4 - g cost - 1 (used to check surrounding cells)
# check east cell
east_cell_check:
        add     $t3, $s1, 8             # get costcell address of cell to the east
        lw      $t4, 0($t3)             # t4 - h cost of east cell
        lw      $t5, 4($t3)             # t5 - g cost of east cell
        beq     $t4, $s7, south_cell_check      # continue if already updated
        bne     $s5, $t5, south_cell_check      # continue if current cell isnt on the path
east_inner_east_check:
        add     $t2, $t3, 8             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, east_inner_south_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, south_cell_check
east_inner_south_check:
        add     $t2, $t3, 240             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, east_inner_north_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, south_cell_check
east_inner_north_check:
        sub     $t2, $t3, 240             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, east_add        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, south_cell_check
east_add:
        mul     $t0, $t1, 4             # mult size of queue by 4
        add     $t0, $t0, $s2           # add that size to starting address of queue
        sw      $t3, 0($t0)             # store east cell for pending update
        add     $t1, $t1, 1             # increment size by one
# check south cell
south_cell_check:
        add     $t3, $s1, 240             # get costcell address of cell to the south
        lw      $t4, 0($t3)             # t4 - h cost of west cell
        lw      $t5, 4($t3)             # t5 - g cost of west cell
        beq     $t4, $s7, west_cell_check      # continue if already updated
        bne     $s5, $t5, west_cell_check      # continue if current cell isnt on the path
south_inner_east_check:
        add     $t2, $t3, 8             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, south_inner_south_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, west_cell_check
south_inner_south_check:
        add     $t2, $t3, 240             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, south_inner_north_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, west_cell_check
south_inner_west_check:
        sub     $t2, $t3, 8             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, south_add        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, west_cell_check
south_add:

        mul     $t0, $t1, 4             # mult size of queue by 4
        add     $t0, $t0, $s2           # add that size to starting address of queue
        sw      $t3, 0($t0)             # store west cell for pending update
        add     $t1, $t1, 1             # increment size by one

# check west cell
west_cell_check:
        sub     $t3, $s1, 8             # get costcell address of cell to the west
        lw      $t4, 0($t3)             # t4 - h cost of west cell
        lw      $t5, 4($t3)             # t5 - g cost of west cell
        beq     $t4, $s7, north_cell_check      # continue if already updated
        bne     $s5, $t5, north_cell_check      # continue if current cell isnt on the path
west_inner_west_check:
        sub     $t2, $t3, 8             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, west_inner_south_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, north_cell_check
west_inner_south_check:
        add     $t2, $t3, 240             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, west_inner_north_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, north_cell_check
west_inner_north_check:
        sub     $t2, $t3, 240             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, west_add        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, north_cell_check
west_add:
        mul     $t0, $t1, 4             # mult size of queue by 4
        add     $t0, $t0, $s2           # add that size to starting address of queue
        sw      $t3, 0($t0)             # store west cell for pending update
        add     $t1, $t1, 1             # increment size by one
# check north cell
north_cell_check:
        sub     $t3, $s1, 240             # get costcell address of cell to the north
        lw      $t4, 0($t3)             # t4 - h cost of north cell
        lw      $t5, 4($t3)             # t5 - g cost of north cell
        beq     $t4, $s7, loop_until_allupdated      # continue if already updated
        bne     $s5, $t5, loop_until_allupdated      # continue if current cell isnt on the path
north_inner_east_check:
        add     $t2, $t3, 8             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, north_inner_south_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, loop_until_allupdated
north_inner_west_check:
        sub     $t2, $t3, 8             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, north_inner_north_check        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, loop_until_allupdated
north_inner_north_check:
        sub     $t2, $t3, 240             # get costcell address to the east of the east address
        lw      $t6, 0($t2)             # second h cost
        lw      $t7, 4($t2)             # load g cost of other cell # create second check to make sure not updateing wrong thing
        bne     $t7, $s4, north_add        # if g cost isnt the same as curr g cost, 
        bne     $t6, $s7, loop_until_allupdated
north_add:
        mul     $t0, $t1, 4             # mult size of queue by 4
        add     $t0, $t0, $s2           # add that size to starting address of queue
        sw      $t3, 0($t0)             # store north cell for pending update
        add     $t1, $t1, 1             # increment size by one

        j       loop_until_allupdated
update_finished:
        jr      $ra


#######################################
# moves one cell in the dir currently facing
move_one_cell:
        sub     $sp, $sp, 8
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)

        li      $s0, 10
        sw      $s0, VELOCITY($0)
        lw      $s0, TIMER($0)
        add     $s0, $s0, 10000
        sw      $s0, TIMER($0)
moving_loop:
        lw      $s0, VELOCITY($0)
        bne     $s0, $0, moving_loop

        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        add     $sp, $sp, 8
        jr      $ra

#######################################
move_east: # function to move east, to be used when we do actual pathfinding
        li      $t1, 2
        li        $t5, 1
        sw        $0, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        jal     move_one_cell
        j       infinite
move_west: # function to move west, to be used when we do actual pathfinding
        li      $t1, 4
        li        $t4,  180
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        jal     move_one_cell
        j       infinite
move_north: # function to move north, to be used when we do actual pathfinding
        li      $t1, 1
        li        $t4, 270
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        jal     move_one_cell
        j       infinite
move_south: # function to move south, to be used when we do actual pathfinding
        li      $t1, 3
        li        $t4, 90
        li        $t5, 1
        sw        $t4, ANGLE($0)
        sw        $t5, ANGLE_CONTROL($0)
        jal     move_one_cell
        j       infinite

solve_puzzle: # function to solve a puzzle (must have requested a puzzle first)
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
        jr        $ra
load_treasure_map: # get the treasure_map struct
        la        $t2, treasure_map
        sw        $t2, TREASURE_MAP($0)
        jr        $ra
pick_treasure: # function to pick up treasure
        sw        $0, PICK_TREASURE($0)
        jr        $ra
load_maze_map:
        la        $t2, maze_map
        sw        $t2, MAZE_MAP($0)
        j         continue


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

        and       $a0, $k0, REQUEST_PUZZLE_INT_MASK
        bne       $a0, 0, request_puzzle_interrupt

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
        sw        $v0, REQUEST_PUZZLE_ACK     # acknowledge interrupt
        j         interrupt_dispatch          # see if other interrupts are waiting

timer_interrupt:
        sw        $a1, TIMER_ACK($0)          # acknowledge interrupt
        sw      $0, VELOCITY($0)
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