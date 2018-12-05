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

.data
ALL_VALUES: .word 65535

.globl has_single_bit_set
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

.globl get_square_begin
get_square_begin:
	# round down to the nearest multiple of 4
	div	$v0, $a0, 4
	mul	$v0, $v0, 4
	jr	$ra


rule2:
    sub $sp, $sp ___
    sw $ra, 0($sp)
    sw $s0, 4($sp) # i iterator
    sw $s1, 8($sp) # j iterator
    sw $s2, 12($sp) # changed
    sw $s3, 16($sp) # board
    sw $s4, 20($sp) # k iterator
    sw $s5, 24($sp) # l iteator

    li $s0, 0
    li $s2, 0
    move $s3, $a0

loop_i:
    li $s1, 0
    
    blt $s0, 16, loop_j
    move $v0, $s2
    j end

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
    beq $s4, $s0, loop_k_part1_one

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
    bne ALL_VALUES, $t0, all_values_jsum_cond
    bne ALL_VALUES, $t1, all_values_isum_cond


all_values_jsum_cond:
    not $t0, $t0
    and $t3, $t0, ALL_VALUES
    sh $t3, 0($t2)
    li $s2, 1
    
    j loop_end_j

all_values_isum_cond:
    not $t1, $t1
    and $t3, $t1, ALL_VALUES
    sh $t3, 0($t2)
    li $s2, 1
    
    j loop_end_j

loop_end_j:
    add $s1, $s1, 1
    j loop_j

loop_end_i:
    add $s0, $s0, 1
    j loop_1

end:
    lw $ra, 0($sp)
    lw $s0, 4($sp) # i iterator
    lw $s1, 8($sp) # j iterator
    lw $s2, 12($sp) # changed
    lw $s3, 16($sp)
    add $sp, $sp ___

    jr $ra
