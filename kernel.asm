bits	16

org		0

CpR	equ	80	; 80 characters per row
RpS	equ	25	; 25 rows per screen
BpC	equ	2	; 2 bytes per character
 

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
	
	; set PIT timer
	mov		al, 0x36
	out		0x43, al    ;tell the PIT which channel we're setting

	mov		ax, 4972		; 240 hz 1193182 / 240 = 4972
	out		0x40, al    ;send low byte
	mov		al, ah
	out		0x40, al    ;send high byte
	
	popa		; I do not want to jump into the yield function because
	pop		es
	pop		ds
	iret		; I do not want to execute the default int 8 handler
	
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
	push	word ds
	push	word es
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
	push	word ds
	push	word es
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
	pop		es
	pop		ds
	jmp	far [cs:ivt8_offset]
	
task0:
	mov		bx, 0xb800
	mov		es, bx
	
	mov		al, '0'
	mov		ah, 0x0F
	mov		[es:80], ax
	
	mov		ah, 0x00
	mov		[es:80], ax
	jmp		task0
task1:
	mov		bx, 0xb800
	mov		es, bx
	
	mov		al, '1'
	mov		ah, 0x0F
	mov		[es:240], ax
	
	mov		ah, 0x00
	mov		[es:240], ax
	jmp		task1
task2:
	mov		bx, 0xb800
	mov		es, bx
	
	mov		al, '2'
	mov		ah, 0x0F
	mov		[es:400], ax
	
	mov		ah, 0x00
	mov		[es:400], ax
	jmp		task2
task3:
	mov dx, str_prompt
	call puts
	
.top:

	mov 	ah, 0x00		; AL holds [cur_char]
	int 	0x16

	cmp		ah, 0x1c	; check for \n
	je		.print

	mov ah, 0x0e		; echo input back onto the screen
	int 0x10

	cmp		al, '0'					; IF char = 0-9
	jb		.non_digit				; THEN jmp to non-digit testing
	cmp		al , '9'
	ja		.non_digit

	xor		dx, dx					; ELSE push onto the stack
	sub 	al, '0'					; convert al to int
	movzx 	dx, al
	call 	_push_value
	
	jmp		.top					; get more chars
	
.non_digit:

	; check for operators
	cmp 	al, '+'	; check for add(+)
	je		.add
	cmp		al, '-'	; check for sub(-)
	je		.sub
	cmp		al, '~'	; check for neg(~)
	je		.neg
	cmp		al, '*'	; check for mul(*)
	je		.mul
	cmp		al, '/'	; check for div(/)
	je		.div
	
	jmp		.top

	
; add top two nums on RPN stack.  Pushes result (in DX) back onto RPN stack
; clobbers DX which holds result
.add:
	push bx

	call _pop_value
	mov bx, dx
	call _pop_value
	add dx, bx

	call _push_value
	
	pop bx
	jmp		.top

; subtract top two nums on RPN stack.  Result in DX
; clobbers DX which holds result
.sub:
	push bx

	call _pop_value	; 1st value stored in bx
	mov bx, dx
	call _pop_value	; 2nd value stored in dx
	sub dx, bx

	call _push_value
	
	pop bx
	jmp		.top
	
; negate top num on RPN stack.  Result in dx
; clobbers DX which holds result
.neg:

	inc word [push_count]
	call _pop_value
	neg 	dx
	call _push_value


	jmp		.top
	
; multiply top two nums on RPN stack.  Result in dx
; clobbers DX which holds result
.mul:
	push ax
	call 	_pop_value
	mov 	ax, dx
	call 	_pop_value
	imul 	dx, ax

	call _push_value

	pop ax
	jmp		.top

; divide top two nums on RPN stack.  Result in dx
; clobbers DX which holds result
.div:
	push ax
	push bx
	call _pop_value
	mov		bx, dx		; numerator in bx
	call _pop_value
	mov 	ax, dx		; denominator in ax
	cdq
	idiv bx				; ax holds quotient

	mov dx, ax
	call _push_value

	pop bx
	pop ax
	jmp		.top

; Inserts top value of RPN_stack into num_str(string buffer)
; prints num_str using BIOS int 0x10
; clobbers nothing
; returns nothing
.print:
    push ax
    push bx
	push cx
	push dx

	mov ah, 0x0e
	mov al, 13
	int 0x10		; print \n
	mov al, 10
	int 0x10		; print \r
	mov al, '['
	int 0x10		; print first bracket

	mov bx, [RPN_sp]
	mov ax, [RPN_stack + bx]	; ax holds number to display

	cmp ax, 0
	jge .positive				; if ax is negative
	mov bx, ax
	mov ah, 0x0e
	mov al, '-'					; print neg sign (-)
	int 0x10
	neg bx						; then proceed to print ax positive
	mov ax, bx

.positive:
	mov bx, 10		; bx = iterator for print_str buffer, also holds number of digits
	mov cx, 10		; divider

; place AX value into a 5 index buffer.  Ex: 1234 = {0,1,2,3,4}
.fillbuf:
	sub bx, 2
	xor dx, dx
	idiv cx						; ax = quotient, dx = remainder
	mov [num_str + bx], dx		; throw remainder into print_str
	cmp ax, 0
	jne .fillbuf

; print the contents of num_str
.print_str:
	mov dx, [num_str + bx]		; dx holds an int 0-9
	add dx, '0'					; convert int to ASCII
	mov ah, 0x0e
	mov al, dl
	int 0x10
	add bx, 2
	cmp bx, 10					; stops printing when out of digits
	jl .print_str
.done:

	mov al, ']'
	int 0x10		; print last bracketmov ah, 0x0e
	mov al, 13
	int 0x10		; print \n
	mov al, 10
	int 0x10		; print \r

	pop dx
	pop cx
    pop bx
    pop ax
    
	jmp .top
	
; no parameters
; pushes given value in DX onto RPN stack
; clobbers nothing
; returns nothing
_push_value:
	push bx
	
	add 	word [RPN_sp], 2		; move sp up RPN stack

	mov 	bx, [RPN_sp]			; move value of RPN sp into bx
	mov 	[RPN_stack + bx], dx	; push dx[cur_num] on top of RPN stack

	inc 	word [push_count]

	pop bx
	ret

; pops value off RPN stack
; returns popped value in DX
; clobbers nothing except DX, which holds return value
_pop_value:
	push bx
	; TODO: Handle this whole EXIT thing because exiting the prog would kill multitasking
	cmp		word [push_count], 0
	jle		.reset
	
	mov		bx, [RPN_sp]				; move value of RPN sp into ecx
	mov		dx, [RPN_stack + bx]		; move into dx value at current spot in the stack
	sub		word [RPN_sp], 2 			; move sp down the stack
	
	dec		word [push_count]
	pop bx
	ret

.reset:
	mov dx, str_reset_prompt
	call puts
	jmp task3.top
	
	
; print NUL-terminated string from DS:DX to screen using BIOS (INT 10h)
; takes NUL-terminated string pointed to by DS:DX
; clobbers nothing
; returns nothing
puts:
	push	ax
	push	cx
	push	si
	
	mov	ah, 0x0e
	mov	cx, 1		; no repetition of chars
	
	mov	si, dx
.loop:	mov	al, [si]
	inc	si
	cmp	al, 0
	jz	.end
	int	0x10
	jmp	.loop
.end:
	pop	si
	pop	cx
	pop	ax
	ret
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

; rpn
RPN_stack				times	100 dw 0; ; reserve 100 [word] size spaces, all 0 by default
RPN_sp					dw 	0 ; stack pointer for the RPN stack
num_str					times   5   dw 0; ; buffer to hold up to a 5 digit number
push_count				dw  0 ; checker for stack underflow
; string literals
str_reset_prompt 		db	13, 10, "Stack Underflow >:(", 13, 10, "Try something different...", 13, 10, 0
str_prompt				db	"RPN Calculator, now ported to DOS!", 13, 10,"Input your equation.", 13, 10, 0