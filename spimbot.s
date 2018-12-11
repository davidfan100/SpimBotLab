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
GET_KEYS                = 0xffff00e4
REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4
BREAK_WALL              = 0xffff0000


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
sudoku:       .space 512                       # puzzle is stored as tree-based array
puzzle_res:     .word 1                             # the solution to the puzzle
puzzle_start:   .word 1                             # boolean flag to tell us when to start requesting puzzles
bool_for_rule_1: .word 1
treasure_map:   .space 404                         # treasure map array, each treasure has x and y location, and point value
closest_treasure_index: .word 1
shortest_treasure_distance_squared: .word 1000
puzzle_requested: .word 1                           # boolean flag to say that a puzzle is being requested
prev_wall:      .word 1
largest_treasure_x:     .word 1000
largest_treasure_y:     .word 1000
maze_map:       .byte 0:3600                        # maze map
unexplored:     .byte 1:900                     # array with char (0 = been to, 1 = havent been to)

.text
main:
        #Fill in your code here
        li      $t4, TIMER_INT_MASK               # timer interrupt enable bit
        or      $t4, $t4, BONK_INT_MASK           # bonk interrupt bit
        or      $t4, $t4, REQUEST_PUZZLE_INT_MASK # request puzzle int mask
        or      $t4, $t4, 1                       # global interrupt enable
        mtc0    $t4, $12                          # set interrupt mask (Status register)
        
        sub     $sp, $sp, 8
        sw      $t0, 0($sp)
        sw      $t2, 4($sp)
        # REQUEST TIMER INTERRUPT 
        # lw      $v0, TIMER($0)                    # read current time
        # jr      $ra                               # ret
        lw      $a1, RIGHT_WALL_SENSOR            # prev right wall
        sw      $a1, prev_wall($0)
        sw      $0, puzzle_requested
        j       load_treasure_map
        j       find_largest_treasure

begin_infinite:
        lw      $t0, GET_KEYS($0)
        bge     $t0, 6, infinite
        lw      $t0, puzzle_requested
        beq     $t0, 0, req_puzzle
        lw      $t0, puzzle_start
        beq     $t0, 1, solve_puzzle
infinite:     
        # need to write code to keep track of whenever we have found a treasure

        la      $t0, unexplored
        mul     $t6, $s1, 30
        add     $t6, $t6, $s0                   # getting unexplored index for curr pos
        add     $t6, $t6, $t0
        lbu     $t7, 0($t6)

        beq     $t7, $0, dont_load_map               # unexplored == 1 : havent explored yet

        jal     load_maze_map
        sb      $0, 0($t6)                     # updates unexplored to 0 (explored)

dont_load_map:
        lw      $s2, largest_treasure_x($0)                     # s2 - x-goal 
        lw      $s3, largest_treasure_y($0)                 # s3 - y-goal 

        lw      $s0, BOT_X($0)
        div     $s0, $s0, 10                # s0 - x
        lw      $s1, BOT_Y($0)
        div     $s1, $s1, 10                # s1 - y

        beq     $s0, $s2, x_accurate
        beq     $s1, $s3, continue_checks
        lw      $t5, VELOCITY($0)
        bne     $t5, $0, continue

x_accurate:
        beq     $s1, $s3, correct_loc

continue_checks:
        la      $t2, maze_map
        mul     $t1, $s1, 120
        mul     $t3, $s0, 4
        add     $t1, $t1, $t3   

        add     $s4, $t1, $t2               # s4 - curr cell maze map

        slt     $s5, $s1, $s3                    # $s5: 1 - south, 0 - north
        slt     $s6, $s0, $s2                    # $s6: 1 - east, 0 - west

        li      $v0, PRINT_INT

        # NORTH SOUTH CHECK FIRST
north_south_check:
        beq     $s1, $s3, east_west_check
        beq     $s5, $0, go_north
go_south:
        lbu     $s7, 0($s4)                 # s7 - south wall
        beq     $s7, $0, east_west_check    # go to next check if there is a wall
        jal     move_south
        j       continue
go_north:
        lbu      $s7, 2($s4)
        beq     $s7, $0, east_west_check
        jal     move_north
        j       continue

# assumes south/north has a wall
east_west_check:
        beq     $s0, $s2, break_north_south
        beq     $s6, $0, go_west
go_east:
        lbu      $s7, 3($s4)                 # s7 - east wall
        beq     $s7, $0, break_east_wall         #
        jal     move_east
        j       continue
go_west: 
        lbu      $s7, 1($s4)
        beq     $s7, $0, break_west_wall
        jal     move_west
        j       continue



break_east_wall:
        li      $t0, 3
        sw      $t0, BREAK_WALL($0)
        jal     move_east
        j       continue
break_west_wall:
        li      $t0, 1
        sw      $t0, BREAK_WALL($0)
        jal     move_west
        j       continue
break_north_wall:
        li      $t0, 2
        sw      $t0, BREAK_WALL($0)
        jal     move_north
        j       continue

break_north_south:
        beq     $s5, $0, break_north_wall

break_south_wall:
        li      $t0, 0
        sw      $t0, BREAK_WALL($0)
        jal     move_south
        j       continue

correct_loc:
        sw      $0, VELOCITY($0)

continue:
        j       find_largest_treasure
        #j       find_closest_treasure

finish_finding:
        bne     $s0, $s2, end_loop
        bne     $s1, $s3, end_loop
        j       pick_treasure
end_loop:
        j       begin_infinite
load_maze_map:
        sub     $sp, $sp, 4
        sw      $ra, 0($sp)
        la        $v0, maze_map
        sw        $v0, MAZE_MAP($0)
        lw      $ra, 0($sp)
        add     $sp, $sp, 4
        jr        $ra

move_east: # function to move east, to be used when we do actual pathfinding
        sub     $sp, $sp, 16
        sw      $ra, 0($sp)
        sw      $s4, 4($sp)
        sw      $s5, 8($sp)
        sw      $s0, 12($sp)
        li      $s4, 0
        li      $s5, 1
        sw      $s4, ANGLE($0)
        sw      $s5, ANGLE_CONTROL($0)
        li      $s0, 10
        sw      $s0, VELOCITY($0)
        lw      $ra, 0($sp)
        lw      $s4, 4($sp)
        lw      $s5, 8($sp)
        lw      $s0, 12($sp)
        add     $sp, $sp, 16
        jr      $ra
move_west: # function to move west, to be used when we do actual pathfinding
        sub     $sp, $sp, 16
        sw      $ra, 0($sp)
        sw      $s4, 4($sp)
        sw      $s5, 8($sp)
        sw      $s0, 12($sp)
        li      $s4, 180
        li      $s5, 1
        sw      $s4, ANGLE($0)
        sw      $s5, ANGLE_CONTROL($0)
        li      $s0, 10
        sw      $s0, VELOCITY($0)
        lw      $ra, 0($sp)
        lw      $s4, 4($sp)
        lw      $s5, 8($sp)
        lw      $s0, 12($sp)
        add     $sp, $sp, 16
        jr      $ra
move_north: # function to move north, to be used when we do actual pathfinding
        sub     $sp, $sp, 16
        sw      $ra, 0($sp)
        sw      $s4, 4($sp)
        sw      $s5, 8($sp)
        sw      $s0, 12($sp)
        li      $s4, 270
        li      $s5, 1
        sw      $s4, ANGLE($0)
        sw      $s5, ANGLE_CONTROL($0)
        li      $s0, 10
        sw      $s0, VELOCITY($0)
        lw      $ra, 0($sp)
        lw      $s4, 4($sp)
        lw      $s5, 8($sp)
        lw      $s0, 12($sp)
        add     $sp, $sp, 16
        jr      $ra
move_south: # function to move south, to be used when we do actual pathfinding
        sub     $sp, $sp, 16
        sw      $ra, 0($sp)
        sw      $s4, 4($sp)
        sw      $s5, 8($sp)
        sw      $s0, 12($sp)
        li      $s4, 90
        li      $s5, 1
        sw      $s4, ANGLE($0)
        sw      $s5, ANGLE_CONTROL($0)
        li      $s0, 10
        sw      $s0, VELOCITY($0)
        lw      $ra, 0($sp)
        lw      $s4, 4($sp)
        lw      $s5, 8($sp)
        lw      $s0, 12($sp)
        add     $sp, $sp, 16
        jr      $ra
solve_puzzle: # function to solve a puzzle (must have requested a puzzle first)
        # li      $t1, 0   
        # sw      $t1, VELOCITY($0)                 # drive

        la      $a0, sudoku
        jal     rule1
        # sw        $v0, bool_for_rule_1
        # la        $a0, sudoku
        # jal       rule2
        # lw        $s0, bool_for_rule_1
        # or        $t0, $s0, $v0
        bne     $v0, 0, solve_puzzle
        la      $a0, sudoku
        sw      $a0, SUBMIT_SOLUTION($0)
        sw      $0, puzzle_requested($0)
        j       infinite
req_puzzle: # function to request a puzzle
        la      $t2, sudoku
        sw      $t2, REQUEST_PUZZLE($0)
        sw      $0, puzzle_start($0)
        li      $t0, 1
        sw      $t0, puzzle_requested($0)
        # li $s0, 0
        # j         infinite
        j       infinite
# puzzle_wait:
#         lw        $s0, puzzle_start
#         # lw        $s0, 0($sp)
#         # add       $sp, $sp, 8
#         bne       $s0, $0, solve_puzzle
#         sw        $0, VELOCITY($0)
#         j         puzzle_wait

load_treasure_map: # get the treasure_map struct
        la      $t5, treasure_map
        sw      $t5, TREASURE_MAP($0)
        j       end_loop
find_largest_treasure:
        li      $t4, 0                  # index
        la      $t2, treasure_map
        lw      $t3, 0($t2)             # length

        # reset old shortest distance to compute again
        li      $t0, 1000
        sw      $t0, largest_treasure_x($0)
        sw      $t0, largest_treasure_y($0)
largest_loop_treasures:
        # don't modify t4
        mul     $t5, $t4, 8             # struct size offset
        add     $t5, $t5, 4             # length offset
        add     $t1, $t2, $t5
        lw      $t7, 4($t1)             # int points
        li      $t6, 5
        bne     $t6, $t7, keep_looping_largest
set_largest_treasure_coords:
        lh      $t5, 0($t1)             # short i
        lh      $t6, 2($t1)             # short j
        sw      $t5, largest_treasure_x($0)
        sw      $t6, largest_treasure_y($0)
        j       finish_finding
keep_looping_largest:
        add     $t4, $t4, 1
        beq     $t4, $t3, finish_finding
        j       largest_loop_treasures
find_closest_treasure:
        li      $t4, 0                  # index
        la      $t2, treasure_map
        lw      $t3, 0($t2)             # length

        # reset old shortest distance to compute again
        li      $t0, 1000
        sw      $t0, shortest_treasure_distance_squared($0)
loop_treasures:
        # don't modify t4, t5, or t6
        mul     $t5, $t4, 8             # struct size offset
        add     $t5, $t5, 4             # length offset
        add     $t1, $t2, $t5
        lh      $t5, 0($t1)             # short i
        lh      $t6, 2($t1)             # short j
        lw      $t7, 4($t1)             # int points

        lw      $a1, BOT_X($0)
        lw      $a2, BOT_Y($0)
        div     $s1, $a1, 10            # current bot j
        div     $s0, $a2, 10            # current bot i
calculate_distance:
        lw      $s2, shortest_treasure_distance_squared($0)
        sub     $s3, $s0, $t6
        sub     $s4, $s1, $t5
        mul     $s3, $s3, $s3
        mul     $s4, $s4, $s4
        add     $s3, $s3, $s4
        bgt     $s3, $s2, not_closer
        j       set_closest     # comment this line to print debugging info for closest treasure
print_curr_bot_info:
        li      $v0, PRINT_INT
        move    $a0, $t4
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, '>'
        syscall
        li      $v0, PRINT_INT
        move    $a0, $s0
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, ','
        syscall
        li      $v0, PRINT_INT
        move    $a0, $s1
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, '\n'
        syscall

set_closest:
        sw      $t4, closest_treasure_index($0)
        sw      $s3, shortest_treasure_distance_squared($0)

        j       not_closer      # comment this line to print debugging info for closest treasure
print_treasure_info:
        li      $v0, PRINT_INT
        move    $a0, $t4
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, '-'
        syscall
        li      $v0, PRINT_INT
        move    $a0, $t5
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, ','
        syscall
        li      $v0, PRINT_INT
        move    $a0, $t6
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, ','
        syscall
        li      $v0, PRINT_INT
        move    $a0, $t7
        syscall
        li      $v0, PRINT_CHAR
        li      $a0, '\n'
        syscall
not_closer:
        add     $t4, $t4, 1
        beq     $t4, $t3, finish_finding
        j       loop_treasures


pick_treasure: # function to pick up treasure
        sw      $0, PICK_TREASURE($0)
        j       load_treasure_map


has_single_bit_set:
	beq	$a0, 0, hsbs_ret_zero	# return 0 if value == 0
	sub 	$a1, $a0, 1
	and	$a1, $a0, $a1
	bne	$a1, 0, hsbs_ret_zero	# return 0 if (value & (value - 1)) == 0
	li	$v0, 1
	jr	$ra

hsbs_ret_zero:
	li	$v0, 0
	jr	$ra

get_square_begin:
	# round down to the nearest multiple of 4
	div	$v0, $a0, 4
	mul	$v0, $v0, 4
	jr	$ra

##
##
##      Rule 1 Implementation
##
##
board_address:
	mul	$v0, $a1, 16		# i*16
	add	$v0, $v0, $a2		# (i*16)+j
	sll	$v0, $v0, 1		# ((i*9)+j)*2
	add	$v0, $a0, $v0
	jr	$ra

rule1:
	sub	$sp, $sp, 32 		
	sw	$ra, 0($sp)		# save $ra and free up 7 $s registers for
	sw	$s0, 4($sp)		# i
	sw	$s1, 8($sp)		# j
	sw	$s2, 12($sp)		# board
	sw	$s3, 16($sp)		# value
	sw	$s4, 20($sp)		# k
	sw	$s5, 24($sp)		# changed
	sw	$s6, 28($sp)		# temp
	move	$s2, $a0		# store the board base address
	li	$s5, 0			# changed = false

	li	$s0, 0			# i = 0
r1_loop1:
	li	$s1, 0			# j = 0
r1_loop2:
	move	$a0, $s2		# board
	move 	$a1, $s0		# i
	move	$a2, $s1		# j
	jal	board_address
	lhu	$s3, 0($v0)		# value = board[i][j]
	move	$a0, $s3		
	jal	has_single_bit_set
	beq	$v0, 0, r1_loop2_bot	# if not a singleton, we can go onto the next iteration

	li	$s4, 0			# k = 0
r1_loop3:
	beq	$s4, $s1, r1_skip_row	# skip if (k == j)
	move	$a0, $s2		# board
	move 	$a1, $s0		# i
	move	$a2, $s4		# k
	jal	board_address
	lhu	$t0, 0($v0)		# board[i][k]
	and	$t1, $t0, $s3		
	beq	$t1, 0, r1_skip_row
	not	$t1, $s3
	and	$t1, $t0, $t1		
	sh	$t1, 0($v0)		# board[i][k] = board[i][k] & ~value
	li	$s5, 1			# changed = true
	
r1_skip_row:
	beq	$s4, $s0, r1_skip_col	# skip if (k == i)
	move	$a0, $s2		# board
	move 	$a1, $s4		# k
	move	$a2, $s1		# j
	jal	board_address
	lhu	$t0, 0($v0)		# board[k][j]
	and	$t1, $t0, $s3		
	beq	$t1, 0, r1_skip_col
	not	$t1, $s3
	and	$t1, $t0, $t1		
	sh	$t1, 0($v0)		# board[k][j] = board[k][j] & ~value
	li	$s5, 1			# changed = true

r1_skip_col:	
	add	$s4, $s4, 1		# k ++
	blt	$s4, 16, r1_loop3

	## doubly nested loop
	move	$a0, $s0		# i
	jal	get_square_begin
	move	$s6, $v0		# ii
	move	$a0, $s1		# j
	jal	get_square_begin	# jj

	move 	$t0, $s6		# k = ii
	add	$t1, $t0, 4		# ii + GRIDSIZE
	add 	$s6, $v0, 4		# jj + GRIDSIZE

r1_loop4_outer:
	sub	$t2, $s6, 4		# l = jj  (= jj + GRIDSIZE - GRIDSIZE)

r1_loop4_inner:
	bne	$t0, $s0, r1_loop4_1
	beq	$t2, $s1, r1_loop4_bot

r1_loop4_1:	
	mul	$v0, $t0, 16		# k*16
	add	$v0, $v0, $t2		# (k*16)+l
	sll	$v0, $v0, 1		# ((k*16)+l)*2
	add	$v0, $s2, $v0		# &board[k][l]
	lhu	$v1, 0($v0)		# board[k][l]
   	and	$t3, $v1, $s3		# board[k][l] & value
	beq	$t3, 0, r1_loop4_bot

	not	$t3, $s3
	and	$v1, $v1, $t3		
	sh	$v1, 0($v0)		# board[k][l] = board[k][l] & ~value
	li	$s5, 1			# changed = true

r1_loop4_bot:	
	add	$t2, $t2, 1		# l++
	blt	$t2, $s6, r1_loop4_inner

	add	$t0, $t0, 1		# k++
	blt	$t0, $t1, r1_loop4_outer
	

r1_loop2_bot:	
	add	$s1, $s1, 1		# j ++
	blt	$s1, 16, r1_loop2

	add	$s0, $s0, 1		# i ++
	blt	$s0, 16, r1_loop1

	move	$v0, $s5		# return changed
	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	add	$sp, $sp, 32
	jr	$ra


##
##
## Rule 2 Implementation
##
##
rule2:
        sub       $sp, $sp, 36
        sw        $ra, 0($sp)
        sw        $s0, 4($sp) # i iterator
        sw        $s1, 8($sp) # j iterator
        sw        $s2, 12($sp) # changed
        sw        $s3, 16($sp) # board
        sw        $s4, 20($sp) # k iterator
        sw        $s5, 24($sp) # l iteator
        sw        $s6, 28($sp) # ii
        sw        $s7, 32($sp) # jj

        li        $s0, 0
        li        $s2, 0
        move      $s3, $a0

loop_i:
        li        $s1, 0
    
        blt       $s0, 16, loop_j_part_1
        move      $v0, $s2
        j         end_2

loop_j_part_1:
        beq       $s1, 16, loop_end_i

        mul       $t0, $s0, 16
        add       $t0, $t0, $s1
        mul       $t0, $t0, 2
        add       $t0, $s3, $t0
        lhu       $a0, 0($t0)

        jal       has_single_bit_set

        beq       $v0, 1, loop_end_j

        li        $t0, 0 # jsum
        li        $t1, 0 # isum

        li        $s4, 0

loop_k_part_1_one:
        beq       $s4, 16, loop_j_part_2
        beq       $s4, $s1, loop_k_part_2_one

        mul       $t2, $s0, 16
        add       $t2, $t2, $s4
        mul       $t2, $t2, 2
        add       $t2, $t2, $s3
        lhu       $t2, 0($t2)

        or        $t0, $t0, $t2

loop_k_part_2_one:
        add       $s4, $s4, 1
        beq       $s4, $s0, loop_k_part_1_one

        mul       $t2, $s4, 16
        add       $t2, $t2, $s1
        mul       $t2, $t2, 2
        add       $t2, $t2, $s3
        lhu       $t2, 0($t2)

        or        $t1, $t1, $t2

loop_j_part_2:
        mul       $t2, $s0, 16
        add       $t2, $t2, $s1
        mul       $t2, $t2, 2
        add       $t2, $t2, $s3
        li        $t7, 65535
        bne       $t7, $t0, all_values_jsum_cond
        bne       $t7, $t1, all_values_isum_cond

        move      $a0, $s0
        jal       get_square_begin

        move      $s6, $v0

        move      $a0, $s1
        jal       get_square_begin

        move      $s7, $v0
        li        $t0, 0 # sum
        move      $s4, $s6 # k iterator
        add       $t1, $s6, 4 # ii + 4
        add       $t2, $s7, 4 # jj + 4

loop_k_two:
        beq       $s4, $t1, loop_j_part_3
        move      $s5, $s7

loop_l_part_1:
        beq       $s5, $t2, loop_k_end

        seq       $t3, $s4, $s0
        seq       $t4, $s5, $s1

        and       $t5, $t3, $t4
        beq       $t5, 1, loop_l_end

        mul       $t5, $s4, 16
        add       $t5, $t5, $s5
        mul       $t5, $t5, 2
        add       $t5, $s3, $t5
        lhu       $t5, 0($t5)

        or        $t0, $t0, $t5

loop_l_end:
        add       $s5, $s5, 1
        j         loop_l_part_1

loop_k_end:
        add       $s4, $s4, 1
        j         loop_k_two

loop_j_part_3:
        li        $t3, 65535
        beq       $t3, $t0, loop_end_j

        not       $t1, $t0
        and       $t2, $t1, $t3

        mul       $t3, $s0, 16
        add       $t3, $t3, $s1
        mul       $t3, $t3, 2
        add       $t3, $t3, $s3
        sh        $t2, 0($t3)

        li        $s2, 1

        j         loop_end_j

all_values_jsum_cond:
        not       $t0, $t0
        li        $t3, 65535
        and       $t3, $t0, $t3
        sh        $t3, 0($t2)
        li        $s2, 1
    
        j         loop_end_j

all_values_isum_cond:
        not       $t1, $t1
        li        $t3, 65535
        and       $t3, $t1, $t3
        sh        $t3, 0($t2)
        li        $s2, 1

loop_end_j:
        add       $s1, $s1, 1
        j         loop_j_part_1

loop_end_i:
        add       $s0, $s0, 1
        j         loop_i

end_2:
        lw        $ra, 0($sp)
        lw        $s0, 4($sp) # i iterator
        lw        $s1, 8($sp) # j iterator
        lw        $s2, 12($sp) # changed
        lw        $s3, 16($sp) # board
        lw        $s4, 20($sp) # k iterator
        lw        $s5, 24($sp) # l iteator
        lw        $s6, 28($sp) # ii
        lw        $s7, 32($sp) # jj
        add       $sp, $sp, 36

        jr        $ra


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
        sw        $0, VELOCITY($0)
        j         interrupt_dispatch          # see if other interrupts are waiting

request_puzzle_interrupt:
	sw	  $a1, REQUEST_PUZZLE_ACK($0)     # acknowledge interrupt
        li        $t1, 1
        sw        $t1, puzzle_start
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
