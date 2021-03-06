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

	mov		ax, 4972		; 60 hz 1193182 / 60 = 19886
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
	mov		cx, 39			; display x coord
.top:
	mov		ax, 0
.spin:
	cmp		ax, 5000
	je		.no_spin
	inc		ax
	jmp		.spin
.no_spin:
	mov		si, names_img	; the image to display on the screen
	mov		di, 1			; display y coord
	mov		ax, 5			; image hieght
	mov		dx, 76			; image width
	mov		bx, video_t0	; screen to display the image on
	call	draw_image
	
	dec		cx				; display x coord move right
	cmp		cx, -76
	jge		.no_reset
	mov		cx, 39
.no_reset:
	jmp		.top
task1:
	mov		cx, -20			; display x coord
.top:
	mov		ax, 0
.spin:
	cmp		ax, 3000
	je		.no_spin
	inc		ax
	jmp		.spin
.no_spin:
	mov		si, fishies_img	; the image to display on the screen
	mov		di, 1			; display y coord
	mov		ax, 5			; image hieght
	mov		dx, 20			; image width
	mov		bx, video_t1	; screen to display the image on
	call	draw_image
	
	inc		cx				; display x coord move right
	cmp		cx, 39
	jle		.no_reset
	mov		cx, -20
.no_reset:
	jmp		.top
task2:
	mov		cx, 39			; display x coord
.top:
	mov		ax, 0
.spin:
	cmp		ax, 5000
	je		.no_spin
	inc		ax
	jmp		.spin
.no_spin:
	mov		si, mustang_img	; the image to display on the screen
	mov		di, 3			; display y coord
	mov		ax, 3			; image hieght
	mov		dx, 23			; image width
	mov		bx, video_t2	; screen to display the image on
	call	draw_image
	
	dec		cx				; display x coord move right
	cmp		cx, -23
	jge		.no_reset
	mov		cx, 39
.no_reset:
	jmp		.top
	
; takes a screen pointer in bx
; clears it to black
clear_section:
	push	es
	push	ax
	push	cx
	push	di
	
	
	mov	ax, 0xb800
	mov	es, ax
	
	mov		al, 0
	mov		cx, 80
	mov		di, [bx + 0]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 2]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 4]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 6]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 8]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 10]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 12]
	rep	stosb
	mov		cx, 80
	mov		di, [bx + 14]
	rep	stosb
	
	pop		di
	pop		cx
	pop		ax
	pop		es
	ret
	
start_x		equ	-2
start_y		equ	-4
x_dif		equ	-6
y_dif		equ	-8
start_x2	equ	-10
start_y2	equ	-12
	
; bx is the screen to print to
; si is the image to print
; cx is x to print at
; di is y to print at
; ax is the image hieght
; bx is the image width
draw_image:
	push	cx ;x
	push	di ;y
	push	ax ;hieght
	push	dx ;width
	push	bx ;screen
	push	bp 
	
	mov		bp, sp
	
	push	word 0 ;start x
	push	word 0 ;start y
	push	word 0 ;x dif
	push	word 0 ;y dif
	push	word 0 ;start x times 2
	push	word 0 ;start y times 2
	
	; makes background black
	call	clear_section
	
	mov		[bp + x_dif], cx
	add		[bp + x_dif], dx
	
	mov		[bp + y_dif], di
	add		[bp + y_dif], ax
	
; check negitive x
	cmp		cx, 0
	jnle	.non_neg_x
	mov		[bp + start_x], cx
	neg		cx
	imul	cx, 2
	mov		[bp + start_x2], cx
	mov		cx, 0
	
.non_neg_x:
	
; check negitive y
	cmp		di, 0
	jnle	.non_neg_y
	mov		[bp + start_y], di
	neg		di
	imul	di, 2
	mov		[bp + start_y2], di
	mov		di, 0
	
.non_neg_y:
	
; check if x + width is greater than 40
	cmp		word [bp + x_dif], 40
	jle		.goodx
	sub		word [bp + x_dif], 40
	sub		dx, [bp + x_dif]
.goodx:

; check if y + height is greater than 8
	cmp		word [bp + y_dif], 8
	jle		.goody
	sub		word [bp + y_dif], 8
	sub		ax, [bp + y_dif]
.goody:

	; video memory is 2 bytes per slot so multiplying x and y by 2
	imul	cx, 2
	imul	di, 2
	
	; set screen to start at (x,y)
	add		bx, di
	mov		bx, [bx]
	add		bx, cx
	
	; set di to the hieght variable
	mov		di, ax
	
	; change hieght and width
	add		di, [bp + start_y]
	add		dx, [bp + start_x]
	
	add		si, [bp + start_y2] ; starts drawing at start_y2 below the top of the image
	
.top:
	mov		ax, [si]
	add		ax, [bp + start_x2]	; start the line at start_x2 to the right of the begining of the image
	call	print_line
	
	add		bx, 160		;new line in memory
	add		si, 2		;new line image
	dec		di			;decrement the count
	cmp		di, 0
	jg		.top
	
	add		sp, 12
	pop		bp
	pop		bx ;screen
	pop		dx ;hieght
	pop		ax ;width
	pop		di ;y
	pop		cx ;x
	ret
	
; bx start
; ax line
; dx line length
print_line:
	push	dx
	push	bx
	push	si
	push	ax
	push	es
	mov		si, ax
	
	mov		ax, 0xb800
	mov		es, ax
	
.top:
	mov		ax, [si]
	mov		[es:bx], ax
	
	add		si, 2	; next printable word
	add		bx, 2	; next spot to print in
	dec		dx		; decrement the count
	cmp		dx, 0
	jg		.top
	
	pop		es
	pop		ax
	pop		si
	pop		bx
	pop		dx
	ret
	
task3:								; RPN
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

ivt8_offset		dw	0
ivt8_segment	dw	0

; 5 lines, 20 wide
; school of fishies!

fishies_0  dw  0x0F20, 0x0F3E, 0x0F3C, 0x0F28, 0x0F28, 0x0F28, 0x0F27, 0x0F3E, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20
fishies_1  dw  0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F3E, 0x0F3C, 0x0F28, 0x0F28, 0x0F28, 0x0F27, 0x0F3E, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20
fishies_2  dw  0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F3E, 0x0F3C, 0x0F28, 0x0F28, 0x0F28, 0x0F27, 0x0F3E, 0x0F20
fishies_3  dw  0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F3E, 0x0F3C, 0x0F28, 0x0F28, 0x0F28, 0x0F27, 0x0F3E, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20
fishies_4  dw  0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F3E, 0x0F3C, 0x0F28, 0x0F28, 0x0F28, 0x0F27, 0x0F3E, 0x0F20, 0x0F20, 0x0F20

fishies_img dw fishies_0, fishies_1, fishies_2, fishies_3, fishies_4

;<<<<<<<<MUSTANG<<<<<<<<   
; _____/ ____^.*** " . .
;/_@_______@_]***. : .
; 23 by 3

mustang_0 dw 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F4D, 0x0F55, 0x0F53, 0x0F54, 0x0F41, 0x0F4E, 0x0F47, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C, 0x0F3C
mustang_1 dw 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5E, 0x0F2E, 0x0F2A, 0x0F2A, 0x0F2A, 0x0F20, 0x0F2A, 0x0F20, 0x0F2E, 0x0F20, 0x0F2E
mustang_2 dw 0x0F2F, 0x0F5F, 0x0F40, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F40, 0x0F5F, 0x0F5D, 0x0F2A, 0x0F2A, 0x0F2A, 0x0F2E, 0x0F20, 0x0F3A, 0x0F20, 0x0F2E, 0x0F20, 0x0F20

mustang_img dw mustang_0, mustang_1, mustang_2

;    ___       __                   __   ___              __                 
;   /   |     / /  ____ _____  ____/ /  /   |  ____  ____/ /_______ _      __
;  / /| |__  / /  / __ `/ __ \/ __  /  / /| | / __ \/ __  / ___/ _ \ | /| / /
; / ___ / /_/ /  / /_/ / / / / /_/ /  / ___ |/ / / / /_/ / /  /  __/ |/ |/ / 
;/_/  |_\____/   \__,_/_/ /_/\__,_/  /_/  |_/_/ /_/\__,_/_/   \___/|__/|__/  
; 76 by 5

names_0		dw	0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20
names_1		dw	0x0F20, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F20, 0x0F7C, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F20, 0x0F7C, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F5F, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F
names_2		dw	0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F7C, 0x0F20, 0x0F7C, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F60, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F5C, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F7C, 0x0F20, 0x0F7C, 0x0F20, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F5C, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F5F, 0x0F20, 0x0F5C, 0x0F20, 0x0F7C, 0x0F20, 0x0F2F, 0x0F7C, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F
names_3		dw	0x0F20, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F20, 0x0F7C, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F20, 0x0F20, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F7C, 0x0F2F, 0x0F20, 0x0F7C, 0x0F2F, 0x0F20, 0x0F2F, 0x0F20
names_4		dw	0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F20, 0x0F7C, 0x0F5F, 0x0F5C, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F20, 0x0F20, 0x0F5C, 0x0F5F, 0x0F5F, 0x0F2C, 0x0F5F, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F5C, 0x0F5F, 0x0F5F, 0x0F2C, 0x0F5F, 0x0F2F, 0x0F20, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F20, 0x0F7C, 0x0F5F, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F5C, 0x0F5F, 0x0F5F, 0x0F2C, 0x0F5F, 0x0F2F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F20, 0x0F20, 0x0F5C, 0x0F5F, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F7C, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F7C, 0x0F5F, 0x0F5F, 0x0F2F, 0x0F20, 0x0F20

names_img	dw	names_0, names_1, names_2, names_3, names_4

; video memory starting points.
video_t0				dw	CpR + 0*(CpR*2), CpR + 1*(CpR*2),  CpR + 2*(CpR*2),  CpR + 3*(CpR*2),  CpR + 4*(CpR*2),  CpR + 5*(CpR*2), CpR + 6*(CpR*2),  CpR + 7*(CpR*2)
video_t1				dw	CpR + 8*(CpR*2), CpR + 9*(CpR*2),  CpR + 10*(CpR*2),  CpR + 11*(CpR*2),  CpR + 12*(CpR*2),  CpR + 13*(CpR*2), CpR + 14*(CpR*2),  CpR + 15*(CpR*2)
video_t2				dw	CpR + 16*(CpR*2), CpR + 17*(CpR*2),  CpR + 18*(CpR*2),  CpR + 19*(CpR*2),  CpR + 20*(CpR*2),  CpR + 21*(CpR*2), CpR + 22*(CpR*2),  CpR + 23*(CpR*2)

; rpn
RPN_stack				times	100 dw 0; ; reserve 100 [word] size spaces, all 0 by default
RPN_sp					dw 	0 ; stack pointer for the RPN stack
num_str					times   5   dw 0; ; buffer to hold up to a 5 digit number
push_count				dw  0 ; checker for stack underflow
; string literals
str_reset_prompt 		db	13, 10, "Stack Underflow >:(", 13, 10, "Try something different...", 13, 10, 0
str_prompt				db	"RPN Calculator, now ported to DOS!", 13, 10,"Input your equation.", 13, 10, 0