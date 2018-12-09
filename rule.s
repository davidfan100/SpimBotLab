# bool
# rule2(unsigned short board[GRID_SQUARED][GRID_SQUARED]) {
#   bool changed = false;
#   for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
#     for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
#       unsigned value = board[i][j];
#       if (has_single_bit_set(value)) {
#         continue;
#       }
      
#       int jsum = 0, isum = 0;
#       for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
#         if (k != j) {
#           jsum |= board[i][k];        // summarize row
#         }
#         if (k != i) {
#           isum |= board[k][j];         // summarize column
#         }
#       }
#       if (ALL_VALUES != jsum) {
#         board[i][j] = ALL_VALUES & ~jsum;
#         changed = true;
#         continue;
#       } else if (ALL_VALUES != isum) {
#         board[i][j] = ALL_VALUES & ~isum;
#         changed = true;
#         continue;
#       }

#       // eliminate from square
#       int ii = get_square_begin(i);
#       int jj = get_square_begin(j);
#       unsigned sum = 0;
#       for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
#         for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
#           if ((k == i) && (l == j)) {
#             continue;
#           }
#           sum |= board[k][l];
#         }
#       }

#       if (ALL_VALUES != sum) {
#         board[i][j] = ALL_VALUES & ~sum;
#         changed = true;
#       } 
#     }
#   }
#   return changed;
# }

# the address of A[0][0] + (((i*N) + j) * sizeof(element))


.text
has_single_bit_set:
	beq	$a0, 0, hsbs_ret_zero	# return 0 if value == 0
	sub	$a1, $a0, 1
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

rule1:
	sub $sp, $sp, 32
	sw $ra, 0($sp)
	sw $s0, 4($sp) ## changed
	sw $s1, 8($sp) ## i
	sw $s2, 12($sp) ## j
	sw $s3, 16($sp) ## board
	sw $s4, 20($sp) ## board[i][j]
	sw $s5, 24($sp) ## ii
	sw $s6, 28($sp) ## jj

	move $s3, $a0
	li $t0, 0 # changed
	move $s0, $t0
	li $t1, 0 # i
loop_rule_1:
	li $t2, 0 # j

	blt $t1, 16, loop_rule_2
	move $v0, $s0
	j end_1

loop_rule_2:
	move $s1, $t1
	move $s2, $t2

	mul $t3, $s1, 16
	add $t3, $t3, $s2
	mul $t3, $t3, 2
	add $t3, $s3, $t3
	lhu $a0, 0($t3)

	move $s4, $a0 ## moving value board[i][j] to the argument reg

	jal has_single_bit_set

	li $t1, 0 # store values of k
	beq $v0, 1, loop_for_has_bit_1

	j for_next_rule_loop
	
for_next_rule_loop:
	add $t2, $s2, 1
	move $t1, $s1
	blt $t2, 16, loop_rule_2

	add $t1, $s1, 1

	j loop_rule_1

loop_for_has_bit_1: 
	bge $t1, 16, loop_for_has_bit_2_prep
	bne $t1, $s2, if_row 
	bne $t1, $s1, if_column

	add $t1, $t1, 1

	j loop_for_has_bit_1

if_row:
	mul $t2, $s1, 16
	add $t2, $t2, $t1
	mul $t2, $t2, 2
	add $t2, $s3, $t2
	lhu $t3, 0($t2)   #obtaining board[i][k] value

	and $t4, $t3, $s4
	bne $t4, 0, if_row_changing
	bne $t1, $s1, if_column

	add $t1, $t1, 1
	j loop_for_has_bit_1

if_row_changing:
	not $t4, $s4

	and $t5, $t3, $t4
	sh $t5, 0($t2)
	li $s0, 1

	bne $t1, $s1, if_column
	add $t1, $t1, 1

	j loop_for_has_bit_1
	
if_column:
	mul $t2, $t1, 16
	add $t2, $t2, $s2
	mul $t2, $t2, 2
	add $t2, $s3, $t2
	lhu $t3, 0($t2) #obtaining board[k][j]

	and $t4, $t3, $s4
	bne $t4, 0, if_column_changing
	add $t1, $t1, 1
	j loop_for_has_bit_1

if_column_changing:
	not $t4, $s4

	and $t5, $t3, $t4
	sh $t5, 0($t2)
	li $s0, 1

	add $t1, $t1, 1
	j loop_for_has_bit_1

loop_for_has_bit_2_prep:
	move $a0, $s1
	jal get_square_begin
	
	move $s5, $v0
	move $a0, $s2

	jal get_square_begin

	move $s6, $v0

	move $t0, $s5 ## k
	add $t2, $s5, 4## ii + 4 //because the size of each square is 4 x 4
	add $t3, $s6, 4 ## jj+ 4
	j loop_for_has_bit_2_k

loop_for_has_bit_2_k:
	bge $t0, $t2, for_next_rule_loop
	move $t1, $s6 ## l

loop_for_has_bit_2_l:
	seq $t4, $t0, $s1
	seq $t5, $t1, $s2

	and $t6, $t4, $t5

	bne $t6, 0, for_next_rule_loop_bit

	mul $t4, $t0, 16
	add $t4, $t4, $t1
	mul $t4, $t4, 2
	add $t4, $t4, $s3
	lhu $t5, 0($t4)

	and $t6, $t5, $s4
	bne $t6, 0, if_square_changing

	j for_next_rule_loop_bit

if_square_changing:
	not $t6, $s4

	and $t6, $t5, $t6
	sh $t6, 0($t4)

	j for_next_rule_loop_bit

for_next_rule_loop_bit:
	add $t1, $t1, 1
	
	blt $t1, $t3, loop_for_has_bit_2_l

	add $t0, $t0, 1
	j loop_for_has_bit_2_k

end_1:
	lw $s6, 28($sp) # get_square_begin(j)
	lw $s5, 24($sp) # get_square_begin(i)
	lw $s4, 20($sp) ## board[i][j]
	lw $s3, 16($sp) ## board
	lw $s2, 12($sp) ## j
	lw $s1, 8($sp) ## i
	lw $s0, 4($sp) ## changed
	lw $ra, 0($sp)
	add $sp, $sp, 32
	
	jr $ra


rule2:
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp) # i iterator
    sw $s1, 8($sp) # j iterator
    sw $s2, 12($sp) # changed
    sw $s3, 16($sp) # board
    sw $s4, 20($sp) # k iterator
    sw $s5, 24($sp) # l iteator
    sw $s6, 28($sp) # ii
    sw $s7, 32($sp) # jj

    li $s0, 0
    li $s2, 0
    move $s3, $a0

loop_i:
    li $s1, 0
    
    blt $s0, 16, loop_j_part_1
    move $v0, $s2
    j end_2

loop_j_part_1:
    beq $s1, 16, loop_end_i

    mul $t0, $s0, 16
    add $t0, $t0, $s1
    mul $t0, $t0, 2
    add $t0, $s3, $t0
    lhu $a0, 0($t0)

    jal has_single_bit_set

    beq $v0, 1, loop_end_j

    li $t0, 0 # jsum
    li $t1, 0 # isum

    li $s4, 0

loop_k_part_1_one:
    beq $s4, 16, loop_j_part_2
    beq $s4, $s1, loop_k_part_2_one

    mul $t2, $s0, 16
    add $t2, $t2, $s4
    mul $t2, $t2, 2
    add $t2, $t2, $s3
    lhu $t2, 0($t2)

    or $t0, $t0, $t2

loop_k_part_2_one:
    add $s4, $s4, 1
    beq $s4, $s0, loop_k_part_1_one

    mul $t2, $s4, 16
    add $t2, $t2, $s1
    mul $t2, $t2, 2
    add $t2, $t2, $s3
    lhu $t2, 0($t2)

    or $t1, $t1, $t2

loop_j_part_2:
    mul $t2, $s0, 16
    add $t2, $t2, $s1
    mul $t2, $t2, 2
    add $t2, $t2, $s3
    li $t7, 65535
    bne $t7, $t0, all_values_jsum_cond
    bne $t7, $t1, all_values_isum_cond

    move $a0, $s0
    jal get_square_begin

    move $s6, $v0

    move $a0, $s1
    jal get_square_begin

    move $s7, $v0
    li $t0, 0 # sum
    move $s4, $s6 # k iterator
    add $t1, $s6, 4 # ii + 4
    add $t2, $s7, 4 # jj + 4

loop_k_two:
    beq $s4, $t1, loop_j_part_3
    move $s5, $s7

loop_l_part_1:
    beq $s5, $t2, loop_k_end

    seq $t3, $s4, $s0
    seq $t4, $s5, $s1

    and $t5, $t3, $t4
    beq $t5, 1, loop_l_end

    mul $t5, $s4, 16
    add $t5, $t5, $s5
    mul $t5, $t5, 2
    add $t5, $s3, $t5
    lhu $t5, 0($t5)

    or $t0, $t0, $t5

loop_l_end:
    add $s5, $s5, 1
    j loop_l_part_1

loop_k_end:
    add $s4, $s4, 1
    j loop_k_two

loop_j_part_3:
    la $t3, ALL_VALUES
    beq $t3, $t0, loop_end_j

    not $t1, $t0
    and $t2, $t1, $t3

    mul $t3, $s0, 16
    add $t3, $t3, $s1
    mul $t3, $t3, 2
    add $t3, $t3, $s3
    sh $t2, 0($t3)

    li $s2, 1

    j loop_end_j

all_values_jsum_cond:
    not $t0, $t0
    li $t3, 65535
    and $t3, $t0, $t3
    sh $t3, 0($t2)
    li $s2, 1
    
    j loop_end_j

all_values_isum_cond:
    not $t1, $t1
    li $t3, 65535
    and $t3, $t1, $t3
    sh $t3, 0($t2)
    li $s2, 1

loop_end_j:
    add $s1, $s1, 1
    j loop_j_part_1

loop_end_i:
    add $s0, $s0, 1
    j loop_i

end_2:
    lw $ra, 0($sp)
    lw $s0, 4($sp) # i iterator
    lw $s1, 8($sp) # j iterator
    lw $s2, 12($sp) # changed
    lw $s3, 16($sp) # board
    lw $s4, 20($sp) # k iterator
    lw $s5, 24($sp) # l iteator
    lw $s6, 28($sp) # ii
    lw $s7, 32($sp) # jj
    add $sp, $sp, 36

    jr $ra
