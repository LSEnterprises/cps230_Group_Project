bits 16

org 0X100

section .text

start:
	
	mov		ax, [t1_stack + 256]
	mov		[task_stacks + 0*2], ax
	mov		ax, [t2_stack + 256]
	mov		[task_stacks + 1*2], ax
	
	mov		sp, [task_stacks + 0*2]
	push	task1
	push	word 0
	push	word 0
	push	word 0
	push	word 0
	push	word [task_stacks + 0*2]	;sp
	push	word 0
	push	word 0
	push	word 0
	
	mov		sp, [task_stacks + 1*2]
	push	task2
	push	word 0
	push	word 0
	push	word 0
	push	word 0
	push	word [task_stacks + 1*2]	;sp
	push	word 0
	push	word 0
	push	word 0
	
	jmp		begin
	
	ret
	
yeild:
	pusha
begin:
	mov		bx, [cur_task]
	dec		bx
	imul	word bx, 2
	add		bx, [task_stacks]
	mov		[bx], sp
	inc		word [cur_task]
	
	cmp		word [cur_task], 3
	jne		.good
	mov		word [cur_task], 1
.good:
	mov		bx, [cur_task]
	dec		bx
	imul	word bx, 2
	add		bx, [task_stacks]
	mov		sp, [bx]
	
	popa
	ret
	
task1:
	mov		al, '1'
	mov	ah, 0x0e
	int		0x10
	call	yeild
	jmp		task1
task2:
	mov		al, '2'
	mov	ah, 0x0e
	int		0x10
	call	yeild
	jmp		task2
section .data

cur_task	dw	0

task_stacks	times 2		dw	0 ; Array of task stack pointers

t1_stack	times 256	db	0
t2_stack	times 256	db	0