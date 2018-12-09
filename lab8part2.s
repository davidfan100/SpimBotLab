.text

## bool
## rule1(unsigned short board[GRID_SQUARED][GRID_SQUARED]) {
##   bool changed = false;
##   for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
##     for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
##       unsigned value = board[i][j];
##       if (has_single_bit_set(value)) {
##         for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
##           // eliminate from row
##           if (k != j) {
##             if (board[i][k] & value) {
##               board[i][k] &= ~value;
##               changed = true;
##             }
##           }
##           // eliminate from column
##           if (k != i) {
##             if (board[k][j] & value) {
##               board[k][j] &= ~value;
##               changed = true;
##             }
##           }
##         }
## 
##         // elimnate from square
##         int ii = get_square_begin(i);
##         int jj = get_square_begin(j);
##         for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
##           for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
##             if ((k == i) && (l == j)) {
##               continue;
##             }
##             if (board[k][l] & value) {
##               board[k][l] &= ~value;
##               changed = true;
##             }
##           }
##         }
##       }
##     }
##   }
##   return changed;
## }

.globl rule1
rule1:
	sub $sp, $sp, 36		# allocate memory to stack frame
	sw $ra, 0($sp)			# store ra
	sw $s0, 4($sp)			# store i
	sw $s1, 8($sp)			# store j
	sw $s2, 12($sp)			# store changed 
	sw $s3, 16($sp)			# func args
	sw $s4, 20($sp)			# store k
	sw $s5, 24($sp)			# store l
	sw $s6, 28($sp)			# store value
	sw $s7, 32($sp)			# store jj

	li $s2, 0				# changed = false
	move $s3, $a0			# store args
	li $s0, 0				# i iterator
r_loop1:
	li $s1, 0				# j iterator
r_loop2:
	mul $t0, $s0, 16		# i * 16
	add $t0, $t0, $s1		# (i * 16) + j
	mul $t0, $t0, 2			# each short is 2 bytes
	add $s6, $t0, $s3		# offset from array head
	lhu $a0, 0($s6)			# value arg
	jal has_single_bit_set
	beq $v0, 0, skip_loop
	li $s4, 0				# k iterator
r_loop3:
	beq $s4, $s1, skip_row	# skip if k == j
	mul $t0, $s0, 16		# i * 16
	add $t0, $t0, $s4		# (i * 16) + k
	mul $t0, $t0, 2			# each short is 2 bytes
	add $t1, $t0, $s3		# offset from array head
	lhu $t2, 0($t1)			# board[i][k]
	lhu $t3, 0($s6)			# value
	and $t4, $t2, $t3		# board[i][k] & value
	beq $t4, $0, skip_row	# skip if t4 is 0
	not $t5, $t3			# ~value (pseudo)
	and $t2, $t2, $t5		# board[i][k] &=  ̃value
	sh $t2, 0($t1)			# write to board
	li $s2, 1				# changed = true
skip_row:
	beq $s4, $s0, skip_col	# skip if k == i
	mul $t0, $s4, 16		# k * 16
	add $t0, $t0, $s1		# (k * 16) + j
	mul $t0, $t0, 2			# each short is 2 bytes
	add $t1, $t0, $s3		# offset from array head
	lhu $t2, 0($t1)			# board[k][j]
	lhu $t3, 0($s6)			# value
	and $t4, $t2, $t3		# board[k][j] & value
	beq $t4, $0, skip_col	# skip if t4 is 0
	not $t5, $t3			# ~value (pseudo)
	and $t2, $t2, $t5		# board[k][j] &=  ̃value
	sh $t2, 0($t1)			# write to board
	li $s2, 1				# changed = true
skip_col:
	add $s4, $s4, 1			# k++
	blt $s4, 16, r_loop3	# while k < 16
elim_from_square:
	move $a0, $s0			# get_square_begin(i)
	jal get_square_begin
	move $s4, $v0			# int ii / k

	move $a0, $s1			# get_square_begin(j)
	jal get_square_begin
	move $s7, $v0			# int jj / l
	add $t1, $s4, 4			# ii + GRIDSIZE (const)
	add $t2, $s7, 4			# jj + GRIDSIZE (const)
l_loop1:
	move $t0, $s7			# init l
l_loop2:
	# if k-i = 0, then k=i
	# if l-j = 0, then l=j
	sub $t3, $s4, $s0		# k - i
	sub $t4, $t0, $s1		# l - j
	bne $t3, $0, l_cont		# k != i
	bne $t4, $0, l_cont		# l != j
	beq $t4, $t3, cont		# skip if both are equal to 0
l_cont:
	# do not modify s4, t0, t1, t2
	mul $t7, $s4, 16		# k * 16
	add $t7, $t7, $t0		# (k * 16) + l
	mul $t7, $t7, 2			# each short is 2 bytes
	add $t6, $t7, $s3		# offset from array head
	lhu $t7, 0($t6)			# board[k][l]
	lhu $t3, 0($s6)			# value
	and $t4, $t7, $t3		# board[k][l] & value
	beq $t4, $0, cont		# skip if t4 is 0
	not $t5, $t3			# ~value (pseudo)
	and $t7, $t7, $t5		# board[k][l] &=  ̃value
	sh $t7, 0($t6)			# write to board
	li $s2, 1				# changed = true

cont:
	add $t0, $t0, 1			# l++
	blt $t0, $t2, l_loop2	# while l < t2

	add $s4, $s4, 1			# k++
	blt $s4, $t1, l_loop1	# while k < t1
skip_loop:
	add $s1, $s1, 1			# j++
	blt $s1, 16, r_loop2 	# while j < 16

	add $s0, $s0, 1			# i++
	blt $s0, 16, r_loop1	# while i < 16
r_end:
	move $v0, $s2			# return changed (data flow)
	lw $ra, 0($sp)			# load ra
	lw $s0, 4($sp)			# load i
	lw $s1, 8($sp)			# load j
	lw $s2, 12($sp)			# load changed 
	lw $s3, 16($sp)			# func args
	lw $s4, 20($sp)			# load k
	lw $s5, 24($sp)			# load l
	lw $s6, 28($sp)			# load value
	lw $s7, 32($sp)			# load jj
	add $sp, $sp, 36		# deallocate memory from stack frame
	jr	$ra					# return changed (control flow)

