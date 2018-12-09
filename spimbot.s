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
sudoku:       .word 1                       # puzzle is stored as tree-based array
puzzle_res:     .space 1                             # the solution to the puzzle
puzzle_start:   .word 1                             # boolean flag to tell us when to start requesting puzzles
treasure_map:   .word 0:404                         # treasure map array, each treasure has x and y location, and point value

#Insert whatever static memory you need here

.text
main:
        #Fill in your code here
        li        $t4, TIMER_INT_MASK               # timer interrupt enable bit
        or        $t4, $t4, BONK_INT_MASK           # bonk interrupt bit
        or        $t4, $t4, REQUEST_PUZZLE_INT_MASK # request puzzle int mask
        or        $t4, $t4, 1                       # global interrupt enable
        mtc0      $t4, $12                          # set interrupt mask (Status register)
        
        # REQUEST TIMER INTERRUPT 
        # lw      $v0, TIMER($0)                    # read current time
        # jr      $ra                               # ret
        lw        $a1, RIGHT_WALL_SENSOR            # prev right wall
	j 	  req_puzzle
infinite:     
        # need to write code to keep track of whenever we have found a treasure
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
solve_puzzle: # function to solve a puzzle (must have requested a puzzle first)
        # sub       $sp, $sp, 8
        # sw        $ra, 0($sp)
        # sw        $s0, 4($sp)
        la          $a0, sudoku
        jal         rule1
        # move      $s0, $v0
        # la        $a0, sudoku
        # jal       rule2
        # or        $t0, $s0, $v0
        bne       $v0, 0, solve_puzzle
        la        $a0, sudoku
        sw        $a0, puzzle_res($0)
        la        $t2, puzzle_res
        sw        $t2, SUBMIT_SOLUTION($0)
        # lw        $ra, 0($sp)
        # lw        $s0, 4($sp)
        # add       $sp, $sp, 8
        j         infinite
req_puzzle: # function to request a puzzle
        la        $t2, sudoku
        sw        $t2, REQUEST_PUZZLE($0)
        sw        $0, puzzle_start($0)
        # j         infinite

puzzle_wait:
        lw        $t0, puzzle_start
        bne       $t0, $0, solve_puzzle
        sw        $0, VELOCITY($0)
        j         puzzle_wait

load_treasure_map: # get the treasure_map struct
        la        $t2, treasure_map
        sw        $t2, TREASURE_MAP($0)
        j         infinite
pick_treasure: # function to pick up treasure
        sw        $0, PICK_TREASURE($0)
        j         infinite


has_single_bit_set:
	beq	  $a0, 0, hsbs_ret_zero	# return 0 if value == 0
	sub 	  $a1, $a0, 1
	and	  $a1, $a0, $a1
	bne	  $a1, 0, hsbs_ret_zero	# return 0 if (value & (value - 1)) == 0
	li	  $v0, 1
	jr	  $ra

hsbs_ret_zero:
	li	  $v0, 0
	jr	  $ra

get_square_begin:
	# round down to the nearest multiple of 4
	div	  $v0, $a0, 4
	mul	  $v0, $v0, 4
	jr	  $ra

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

.globl rule1
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
        la        $t3, 65535
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
        li        $a1, 180                    # turn 180 degrees
        sw        $a1, ANGLE($0)
        sw        $0,  ANGLE_CONTROL($0)
        j         interrupt_dispatch          # see if other interrupts are waiting

request_puzzle_interrupt:
	sw	  $a1, REQUEST_PUZZLE_ACK     # acknowledge interrupt
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
