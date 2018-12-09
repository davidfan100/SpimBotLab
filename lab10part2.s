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

RIGHT_WALL_SENSOR 		= 0xffff0054
PICK_TREASURE           = 0xffff00e0
TREASURE_MAP            = 0xffff0058

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
#

.data
#REQUEST_PUZZLE returns an int array of length 128

.align 4
dfs:      .word 128
dfs_tree: .word  0:128
puzzle_res: .word 1
puzzle_start: .word 1
num_sols: .word 1
# 0 = move_east, 1 = move_west, 2 = move_north, 3 = move_south, 4 = pick_treasure
treasure_moves: .word 3, 3, 4, 1, 3, 3, 0, 4, 3, 3, 0, 2, 4, 0, 0, 2, 1, 4, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 2, 0, 0, 3, 3, 4, 0, 0, 3, 3, 1, 1, 4, 3, 3, 1, 1, 2, 2, 4
move_index: .word 0
num_moves: .word 60
can_look: .word 0

#
#Put any other static memory you need here
#

.text
main:
	#Fill in your code here

    # enable interrupts
    li          $t4, TIMER_INT_MASK         
    or          $t4, $t4, BONK_INT_MASK     
    or          $t4, $t4, REQUEST_PUZZLE_INT_MASK
    or          $t4, $t4, 1                 # global interrupt enable
    mtc0        $t4, $12                    # set interrupt mask (Status register)

    lw          $a1, RIGHT_WALL_SENSOR      # prev right wall

    la          $t3, num_sols
    sw          $0, num_sols($0)
req_puzzle:
    la          $t2, dfs_tree
    sw          $t2, REQUEST_PUZZLE($0)
infinite:
    lw          $t0, puzzle_start
    bne         $t0, $0, solve_puzzle

    # lw          $a0, RIGHT_WALL_SENSOR        # 1 if wall to right
    # bne         $a0, $0, skip_turn
    # beq         $a0, $a1, skip_turn           # rotate 90 if 0

    # li          $t4, 90
    # sw          $t4, ANGLE($0)
    # sw          $0,  ANGLE_CONTROL($0)
    j           skip_turn
solve_puzzle:
    la          $a0, dfs_tree
    li          $a1, 1                        # int i
    li          $a2, 1                        # int input
    jal         _dfs
    sw          $v0, puzzle_res($0)
    la          $t2, puzzle_res
    sw          $t2, SUBMIT_SOLUTION($0)

    lw          $t4, num_sols($0)
    add         $t4, $t4, 1
    sw          $t4, num_sols($0)

    lw          $t5, num_sols($0)
    blt         $t5, 9, req_another_puzzle
pre_look:
    # REQUEST TIMER INTERRUPT every 10000 cycles
    lw          $v0, TIMER($0)              # read current time
    add         $v0, $v0, 10000
    sw          $v0, TIMER($0)              # request timer interrupt in 10000 cycles
look_for_treasure:
    # after getting 8 keys, start looking for treasure
    lw          $t5, can_look($0)
    beq         $t5, $0, look_for_treasure      # wait for timer interrupt

    li          $t1, 5
    sw          $t1, VELOCITY($0)               # drive

    sw          $0, can_look($0)                # reset can_look

    lw          $t0, move_index($0)
    lw          $t1, num_moves($0)
    beq         $t0, $t1, skip_turn

    la          $t2, treasure_moves
    mul         $t0, $t0, 4
    add         $t0, $t0, $t2
    lw          $t3, 0($t0)                     # get current move

    lw          $t0, move_index($0)
    add         $t0, $t0, 1
    sw          $t0, move_index($0)

    beq         $t3, 0, move_east
    beq         $t3, 1, move_west
    beq         $t3, 2, move_north
    beq         $t3, 3, move_south
    beq         $t3, 4, pick_treasure
req_another_puzzle:
    la          $t2, dfs_tree
    sw          $t2, REQUEST_PUZZLE($0)
    sw          $0, puzzle_start($0)
skip_turn:
    move        $a1, $a0                      # save prev right wall
    sw          $0, VELOCITY($0)             # don't drive
    j           infinite
move_east:
    li          $t4, 0
    li          $t5, 1
    sw          $t4, ANGLE($0)
    sw          $t5, ANGLE_CONTROL($0)
    j           look_for_treasure
move_west:
    li          $t4, 180
    li          $t5, 1
    sw          $t4, ANGLE($0)
    sw          $t5, ANGLE_CONTROL($0)
    j           look_for_treasure
move_north:
    li          $t4, 270
    li          $t5, 1
    sw          $t4, ANGLE($0)
    sw          $t5, ANGLE_CONTROL($0)
    j           look_for_treasure
move_south:
    li          $t4, 90
    li          $t5, 1
    sw          $t4, ANGLE($0)
    sw          $t5, ANGLE_CONTROL($0)
    j           look_for_treasure
pick_treasure:
    sw          $0, PICK_TREASURE($0)
    j           look_for_treasure

##int 
##dfs(int* tree, int i, int input) {
##	if (i >= 127) {
##		return -1;
##	}
##	if (input == tree[i]) {
##		return 0;
##	}
##
##	int ret = DFS(tree, 2 * i, input);
##	if (ret >= 0) {
##		return ret + 1;
##	}
##	ret = DFS(tree, 2 * i + 1, input);
##	if (ret >= 0) {
##		return ret + 1;
##	}
##	return ret;
##}
.globl _dfs
_dfs:
		sub		$sp, $sp, 16		# STACK STORE
		sw 		$ra, 0($sp)		# Store ra
		sw		$s0, 4($sp)		# s0 = tree
		sw		$s1, 8($sp)		# s1 = i
		sw		$s2, 12($sp)	# s2 = input
		move 	$s0, $a0
		move 	$s1, $a1
		move	$s2, $a2
##	if (i >= 127) {
##		return -1;
##	}
_dfs_base_case_one:
        blt     $s1, 127, _dfs_base_case_two	
        li      $v0, -1
        j _dfs_return
##	if (input == tree[i]) {
##		return 0;
##	}
_dfs_base_case_two:

		mul		$t1, $s1, 4
		add		$t2, $s0, $t1
        lw      $t1, 0($t2)  			# tree[i]
        
        bne     $t1, $s2, _dfs_ret_one
        li      $v0, 0
		j _dfs_return
##	int ret = DFS(tree, 2 * i, input);
##	if (ret >= 0) {
##		return ret + 1;
##	}
_dfs_ret_one:
		mul		$a1, $s1, 2
		jal 	_dfs				##	int ret = DFS(tree, 2 * i, input);
        
	
		blt		$v0, 0, _dfs_ret_two	##	if (ret >= 0)
		
		addi	$v0, 1					##	return ret + 1
		j _dfs_return
##	ret = DFS(tree, 2 * i + 1, input);
##	if (ret >= 0) {
##		return ret + 1;
##	}
_dfs_ret_two:
        mul		$a1, $s1, 2
		addi	$a1, 1
		jal 	_dfs				##	int ret = DFS(tree, 2 * i + 1, input);
        
	
		blt		$v0, 0, _dfs_return		##	if (ret >= 0)
		
		addi	$v0, 1					##	return ret + 1
		j _dfs_return
##	return ret;
_dfs_return:
		lw 		$ra, 0($sp)
		lw		$s0, 4($sp)
		lw		$s1, 8($sp)
		lw		$s2, 12($sp)
		add		$sp, $sp, 16
        jal     $ra

.kdata
chunkIH:    .space 28
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at        # Save $at
.set at
        la        $k0, chunkIH
        sw        $a0, 0($k0)        # Get some free registers
        sw        $v0, 4($k0)        # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)

        mfc0      $k0, $13             # Get Cause register
        srl       $a0, $k0, 2
        and       $a0, $a0, 0xf        # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch:            # Interrupt:
    mfc0       $k0, $13        # Get Cause register, again
    beq        $k0, 0, done        # handled all outstanding interrupts

    and        $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
    bne        $a0, 0, bonk_interrupt

    and        $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne        $a0, 0, timer_interrupt

	and 	$a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne 	$a0, 0, request_puzzle_interrupt

    li        $v0, PRINT_STRING    # Unhandled interrupt types
    la        $a0, unhandled_str
    syscall
    j    done

bonk_interrupt:
    #Fill in your code here
    sw          $a1, BONK_ACK($0)               # acknowledge interrupt
    li          $a1, 180                        # turn 180 degrees
    sw          $a1, ANGLE($0)
    sw          $0,  ANGLE_CONTROL($0)
    j           interrupt_dispatch              # see if other interrupts are waiting

request_puzzle_interrupt:
	#Fill in your code here
    sw          $a1, REQUEST_PUZZLE_ACK($0)     # dfs_tree now holds tree
    li          $t1, 1
    sw          $t1, puzzle_start               #solve puzzle in main instead
	j	        interrupt_dispatch

timer_interrupt:
    #Fill in your code here
    sw          $a1, TIMER_ACK($0)              # acknowledge interrupt

    li          $t2, 1
    sw          $t2, can_look                   # can start rotating

    lw          $v0, TIMER($0)                  # read current time
    add         $v0, $v0, 10000
    sw          $v0, TIMER($0)                  # request timer interrupt in 10000 cycles
    j           interrupt_dispatch              # see if other interrupts are waiting

non_intrpt:                # was some non-interrupt
    li          $v0, PRINT_STRING
    la          $a0, non_intrpt_str
    syscall                # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH
    lw      $a0, 0($k0)        # Restore saved registers
    lw      $v0, 4($k0)
	lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

