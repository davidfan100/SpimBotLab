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
    sw $s3, 16($sp)

    move $s0, 0
    move $s1, 0
    move $s2, 0

