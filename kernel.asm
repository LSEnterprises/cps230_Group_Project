bits	16

org		0

IVT8_OFFSET_SLOT	equ	4 * 8			; Each IVT entry is 4 bytes; this is the 8th
IVT8_SEGMENT_SLOT	equ	IVT8_OFFSET_SLOT + 2	; Segment after Offset

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
	
	; set timer interupt
	; Set ES=0x0000 (segment of IVT)
	mov	ax, 0x0000
	mov	es, ax
	
	; disable interrupts (so we can't be...INTERRUPTED...)
	cli
	; save current INT 8 handler address (segment:offset) into ivt8_offset and ivt8_segment
	mov		ax, [es:IVT8_OFFSET_SLOT]
	mov		[ivt8_offset], ax
	mov		ax, [es:IVT8_SEGMENT_SLOT]
	mov		[ivt8_segment], ax
	; set new INT 8 handler address (OUR code's segment:offset)
	mov		ax, yield
	mov		[es:IVT8_OFFSET_SLOT], ax
	mov		ax, cs
	mov		[es:IVT8_SEGMENT_SLOT], ax
	; reenable interrupts (GO!)
	sti
	
	jmp		begin
	
; stack to push to in sp
; begining address of the task in dx
; smashes bx, ax, cx
create_stack:
	pop		bx	; pop return address to free the stack space
	
	mov		cx, cs
	mov		ax, sp
	pushf				; flags 
	push	word cx		; segment of the task
	push	word dx		; offset of the task
	push	word 0
	push	word 0
	push	word 0
	push	word 0
	push	word ax		; sp
	push	word 0
	push	word 0
	push	word 0
	
	push	bx	; restore the return address
	ret
yield:
	cli
	pusha
	
	mov		bx, [cs:cur_task]
	mov		ax, 2
	imul	bx, ax
	add		bx, saved_sps		; compute the correct place to store the current sp
	mov		[cs:bx], sp			; saves sp in the correct task slot
	inc		word [cs:cur_task] 
	
	cmp		word [cs:cur_task], 4	; resets to task 0 after the last task
	jne		.good
	mov		word [cs:cur_task], 0
.good:
	mov		bx, [cs:cur_task]
	mov		ax, 2
	imul	bx, ax
	add		bx, saved_sps		; compute the correct place to retreive the current sp
	mov		sp, [bx]			; retreives the saved sp
	
begin:
	popa
	sti
	jmp	far [cs:ivt8_offset]
	
task0:
	mov		dx, t0_msg
	call	puts
	jmp		task0
task1:
	mov		dx, t1_msg
	call	puts
	jmp		task1
task2:
	mov		dx, t2_msg
	call	puts
	jmp		task2
task3:
	mov		dx, t3_msg
	call	puts
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

ivt8_offset	dw	0
ivt8_segment	dw	0