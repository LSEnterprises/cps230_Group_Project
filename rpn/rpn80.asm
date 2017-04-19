; CpS 230 RPN Calculator: Abraham Steenhoek (astee529)
;---------------------------------------------------
; Assembly program that calcultes basic operations in a postfix math notation style
; Can do math up to 16-bit integers
; Note: all ints are considered DWORDS for this project
; Note: ax, bx, and dx are used for (MOST) arithmetic operations
; Note: bx is also used for ALL operations when manipulating RPN_sp
;---------------------------------------------------

bits 16

org 0x100

section .text

_main:

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
	jmp _main.top
	
section .data

; global variables

RPN_stack				times	100 dw 0; ; reserve 100 [word] size spaces, all 0 by default
RPN_sp					dw 	0 ; stack pointer for the RPN stack
num_str					times   5   dw 0; ; buffer to hold up to a 5 digit number
push_count				dw  0 ; checker for stack underflow
; string literals
str_reset_prompt 		db "Stack Underflow >:(  Try something different...", 13, 10, 0
str_prompt				db	"RPN Calculator, now back with a vengeance at MAXX 100!  Input your equation.", 13, 10, 0