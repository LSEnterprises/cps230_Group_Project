bits	16

org		0x100

section	.text

start:
	mov		sp, stack0
	add		sp, 256
	mov		sp, ax
	push	task0
	push	word 0
	push	word 0
	push	word 0
	push	word 0
	push	word ax		;sp
	push	word 0
	push	word 0
	push	word 0
	
	mov		[saved_sps + 0*2], sp
	
	mov		sp, stack1
	add		sp, 256
	push	task1
	push	word 0
	push	word 0
	push	word 0
	push	word 0
	push	word ax		;sp
	push	word 0
	push	word 0
	push	word 0
	
	mov		[saved_sps + 1*2], sp
	
	jmp		begin
	
yeild:
	pusha
	
	mov		bx, [cur_task]
	mov		ax, 2
	imul	bx, ax
	add		bx, saved_sps
	mov		[bx], sp
	inc		word [cur_task]
	
	cmp		word [cur_task], 2
	jne		.good
	mov		word [cur_task], 0
.good:
	mov		bx, [cur_task]
	mov		ax, 2
	imul	bx, ax
	add		bx, saved_sps
	mov		sp, [bx]
	
begin:
	popa
	ret
task0:
	mov		al, '0'
	mov		ah, 0x0e
	int		0x10
	call	yeild
	jmp		task0
task1:
	mov		al, '1'
	mov		ah, 0x0e
	int		0x10
	call	yeild
	jmp		task1
	
section	.data

cur_task	dw	1

saved_sps	times 2		dw 0

stack0		times 256	db	0
stack1		times 256	db	0