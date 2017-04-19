; CpS 230 Lab 6: Abraham Steenhoek (astee529)
;---------------------------------------------------
; Assembly program that calcultes basic operations in a postfix math notation style
; Note: all ints are considered DWORDS for this project
; Note: eax folds DECIMAL value for current char, and cur_char holds CHAR value for current char
; Note: when indexing an array in this program, ECX is reserved for the stack pointer(sp) and EAX is reserved for the value in the operation
;---------------------------------------------------
; NOTE, fix these dumb comments
; 
bits 16

org 0x100

section .text

_main:

	mov dx, str_prompt
	call puts
	
.top:
	mov bl, al
	mov [prev_char], bl

	mov 	ah, 0x00		; AL holds [cur_char]
	int 	0x16

	cmp		ah, 0x1c	; check for \n
	je		.print


	mov ah, 0x0e		;echo
	int 0x10

	cmp		al, '0'	; IF char = 0-9
	jb		.non_digit				; THEN jmp to non-digit testing
	cmp		al, '9'
	ja		.non_digit

	mov 	bx, [cur_num]			; shift cur_num up one digit
	imul	bx, 10
	mov		[cur_num], bx

	movzx	bx, al					; add cur_char in # form to cur_num
	sub		bx, '0'
	add		word [cur_num], bx
	
	jmp		.top					; get more chars
	
.non_digit:
	;cmp		ax, 0				; terminate of EOF
	;jl		.ret					; return negative value in EAX

	cmp word [prev_char], '0'		; IF last char != 0-9
	jl		.check_ops				; THEN check for operators
	cmp word [prev_char], '9'
	ja		.check_ops
									; ELSE push cur_num onto stack
	mov 	dx, [cur_num]
	call 	_push_value

.check_ops:

	; operators
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

	
; add top two nums on RPN stack.  Pushes result (in BX) back onto RPN stack
; clobbers nothing
.add:
	push bx

	call _pop_value
	mov bx, dx
	call _pop_value
	add dx, bx

	call _push_value
	
	pop bx
	jmp		.top

; subtract top two nums on RPN stack.  Result in eax
.sub:
	push bx

	call _pop_value
	mov bx, dx
	call _pop_value
	sub dx, bx

	call _push_value
	
	pop bx
	jmp		.top
	
; negate top num on RPN stack.  Result in eax
.neg:
	push dx

	call _pop_value
	neg 	dx

	call _push_value

	pop dx
	jmp		.top
	
; multiply top two nums on RPN stack.  Result in eax
.mul:

	jmp		.top

; divide top two nums on RPN stack.  Result in eax
.div:

	jmp		.top

; pops current num value on top of RPN stack and convert it to string
; clobbers nothing
; returns nothing
.print:
    push ax
    push dx
	push bx

	mov ah, 0x0e
	mov al, 13
	int 0x10		; print \n
	mov al, 10
	int 0x10		; print \r
	mov al, '['
	int 0x10		; print first bracket

	mov bx, [RPN_sp]
	mov ax, [RPN_stack]	; ax holds number to display

	mov bx, 5		; bx = iterator for print_str, also holds number of digits
	mov cx, 10		; divider
	;mov ax, dx		
; place popped value from RPN stack into a 5 index buffer.  Ex: 1234 = {0,1,2,3,4}
.fillprintbuf:
	sub bx, 1
	xor dx, dx
	idiv cx						; ax = quotient, dx = remainder
	mov [num_str + bx], dx		; throw remainder into print_str
	cmp ax, 0
	jne .fillprintbuf

; print the contents of num_str
.print_str:
	mov dx, [num_str + bx]		; dx holds an int 0-9
	add dx, '0'					; convert int to ASCII
	mov ah, 0x0e
	mov al, dl
	int 0x10
	add bx, 1
	cmp bx, 5					; stops printing when out of digits
	jl .print_str
.done:

	mov al, ']'
	int 0x10		; print last bracketmov ah, 0x0e
	mov al, 13
	int 0x10		; print \n
	mov al, 10
	int 0x10		; print \r



	pop bx
    pop dx
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

	;inc 	word [push_count]

	mov		word [cur_num], 0

	pop bx
	ret

; pops value off RPN stack
; returns popped value in DX
; clobbers DX - WARNING: replaces whatever was inside DX with popped value
_pop_value:
	push bx
	; TODO: Handle this whole EXIT thing because exiting the prog would kill multitasking
	;cmp		word [push_count], 0
	;jle		.exit
	
	mov		bx, [RPN_sp]				; move value of RPN sp into ecx
	mov		dx, [RPN_stack + bx]		; move into eax value at current spot in the stack
	sub		word [RPN_sp], 2 			; move sp down the stack
	
	;dec		word [push_count]
	pop bx
	ret

.exit:
	mov		dx, str_exit_prompt
	call	puts

	
section .data

; global variables

RPN_stack				times	100 dw 0; ; reserve 100 [word] size spaces, all 0 by default
RPN_sp					dw 	0 ; stack pointer for the RPN stack
num_str					times   5   dw 0; ; buffer to hold up to a 5 digit number
;print_str				db 16 dup (0) ; string buffer
push_count				dw  0 ; checker for stack underflow
cur_char				db  0 ; char value for current char being tested
prev_char				db  0 ; char input before cur_char
cur_num					dw 	0 ; holds current numeric value of input
; string literals
str_exit_prompt 		db "Stack Underflow >:(  Exiting...", 10, 0
str_prompt				db	"RPN Calculator, now back with a vengeance at MAXX 100!  Input your equation.", 13, 10, 0
fmt						db	"[%d]", 10, 0