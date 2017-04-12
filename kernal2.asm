bits	16

org		0x100

section	.text

start: ; stack setup
	mov		sp, stack0				; stack starts at the top address and works down 
	add		sp, 256					; add 256 to get to the top of the stack
	mov		dx, task0
	call	create_stack
	mov		[saved_sps + 0*2], sp
	
	mov		sp, stack1
	add		sp, 256
	mov		dx, task1
	call	create_stack
	mov		[saved_sps + 1*2], sp
	
	mov		sp, stack2
	add		sp, 256
	mov		dx, task2
	call	create_stack
	mov		[saved_sps + 2*2], sp
	
	mov		sp, stack3
	add		sp, 256
	mov		dx, task3
	call	create_stack
	mov		[saved_sps + 3*2], sp
	
	jmp		begin ; begin exicuting the tasks
	
; stack to push to in sp
; begining address of the task in dx
; smashes bx, ax
create_stack:
	pop		bx	; pop return address to free the stack space
	
	mov		ax, sp
	push	word dx
	push	word 0
	push	word 0
	push	word 0
	push	word 0
	push	word ax		;sp
	push	word 0
	push	word 0
	push	word 0
	
	push	bx	; restore the return address
	ret
yeild:
	pusha
	
	mov		bx, [cur_task]
	mov		ax, 2
	imul	bx, ax
	add		bx, saved_sps		; compute the correct place to store the current sp
	mov		[bx], sp			; saves sp in the correct task slot
	inc		word [cur_task] 
	
	cmp		word [cur_task], 4	; resets to task 0 after the last task
	jne		.good
	mov		word [cur_task], 0
.good:
	mov		bx, [cur_task]
	mov		ax, 2
	imul	bx, ax
	add		bx, saved_sps		; compute the correct place to retreive the current sp
	mov		sp, [bx]			; retreives the saved sp
	
begin:
	popa
	ret
task0:
	mov		dx, t0_msg
	call	puts
	call	yeild
	jmp		task0
task1:
	mov		dx, t1_msg
	call	puts
	call	yeild
	jmp		task1
task2:
	mov		dx, t2_msg
	call	puts
	call	yeild
	jmp		task2
task3:
	mov		dx, t3_msg
	call	puts
	call	yeild
	jmp		task3
	
; print NUL-terminated string from DS:DX to screen using BIOS (INT 10h)
; takes NUL-terminated string pointed to by DS:DX
; clobbers nothing
; returns nothing
puts:
	push	ax		; save ax/cx/si
	push	cx
	push	si
	
	mov	ah, 0x0e	; BIOS video services (int 0x10) function 0x0e: put char to screen
	
	mov	si, dx		; SI = pointer to string (offset only; segment assumed to be DS)
.loop:	mov	al, [si]	; AL = current character
	inc	si		; advance SI to point at next character
	cmp	al, 0		; if (AL == 0), stop
	jz	.end
	int	0x10		; call BIOS via interrupt 0x10 (the ASCII char to print is in AL)
	jmp	.loop		; repeat
.end:
	pop	si		; restore si/cx/ax (de-clobber)
	pop	cx
	pop	ax
	ret			; return to caller
section	.data

t0_msg		db	"I am task 0", 13, 10, 0
t1_msg		db	"I am task 1", 13, 10, 0
t2_msg		db	"I am task 2", 13, 10, 0
t3_msg		db	"I am task 3", 13, 10, 0

cur_task	dw	3	; The program starts on task 3 because stack 3's stack is the last to be configured

saved_sps	times 4		dw 0

stack0		times 256	db	0
stack1		times 256	db	0
stack2		times 256	db	0
stack3		times 256	db	0