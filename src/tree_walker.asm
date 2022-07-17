
;
; [[ Tree Walker ]]
; navigates the dialog tree
;
; [ INFO ]
;	Functions
;		void render_page()
;		bool make_choice(uint8 choice)
;		void set_dialog(ptr newpointer)
;		void type(ptr dpointer)
;		void goto(ptr dpointer)
;

; Tree Format
;	2 byte length of description
;	4 byte description reference
;	
;	1 byte number of choices
;	
;	for each choice
;		2 byte length of text
;		4 byte text reference
;		4 byte choice reference
;	
;	1 byte number of function calls
;
;	for each call,
;		4 byte function reference
;		1 byte number of arguments
;		n * 4 byte argument reference

%libname dtree
%include "lib/text.asm" as txt
%include globals.asm as globals
%include runlater.asm as later

%define DESCRIPTION_COLOR 0xFF
%define CHOICE_COLOR 0xFB
%define SLOW_PRINT_DELAY_TICKS 1


; function void render_page()
; Renders the page pointed to by the global dialog_pointer
render_page:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; diable interrupts while rendering
	MOV A, PF
	MOV PF, 0
	PUSH A
	
	; diable cursor blink
	PUSH byte [globals.cursor_enabled]
	MOV A, 0
	MOV [globals.cursor_enabled], AL
	
	; get pointer
	MOVW J:I, [globals.dialog_pointer]
	
	; print description
	MOV A, [globals.cursor_position]
	
	; make sure we don't try to print a zero-length string
	CMP word [J:I], 0
	JE .print_choices
	
	PUSH A
	PUSH byte DESCRIPTION_COLOR
	PUSH word [J:I]
	PUSH word [J:I + 4]
	PUSH word [J:I + 2]
	CALL txt.func_print_string_colored
	MOV [globals.cursor_position], A
	ADD SP, 9
	
.print_choices:
	; dont print zero choices
	MOV C, 0
	MOV CL, [J:I + 6]
	
	ADD I, 7
	ICC J
	
	CMP CL, 0
	JE .function_start

	; print choices
	MOV DH, 0
	MOV DL, AL
	
;	INC DL
;	
;	; scroll if needed
;	CMP DL, 30
;	JB .dont_scroll_1
;	
;	MOV DL, 29
;	
;	PUSH C
;	PUSH D
;	
;	PUSH byte 1
;	CALL txt.func_scroll_screen
;	ADD SP, 1
;	
;	POP D
;	POP C
;	
;.dont_scroll_1:
	
.choice_loop:
	PUSH C
	
	PUSH D
	PUSH byte CHOICE_COLOR
	PUSH word [J:I + 0]
	PUSH word [J:I + 4]
	PUSH word [J:I + 2]
	CALL txt.func_print_string_colored
	MOV [globals.cursor_position], A
	ADD SP, 7
	POP D
	POP C
	
	; increment row
	INC DL
	
	; check scroll
	CMP DL, 30
	JB .dont_scroll_2
	
	MOV DL, 29
	
	PUSH C
	PUSH D
	
	PUSH byte 1
	CALL txt.func_scroll_screen
	ADD SP, 1
	
	POP D
	POP C
	
.dont_scroll_2:
	; increment choice index
	ADD I, 10
	ICC J
	
	; loop
	DEC C
	JNZ .choice_loop
	
	MOV [globals.cursor_position], D
	
.function_start:
	; call functions
	MOV C, 0
	MOV CL, [J:I]
	CMP CL, 0
	JE .return
	INC I
	ICC J
	
	MOVW BP, J:I
	
.function_loop:
	PUSH C
	
	; function pointer
	MOVW A:B, [BP + 0]
	
	; arg count
	MOV D, 0
	MOV DL, [BP + 4]
	ADD BP, 5
	
	MOV I, D
	CMP DL, 0
	JE .function_arg_loop_break
	
.function_arg_loop:
	PUSH word [BP + 2]
	PUSH word [BP + 0]
	ADD BP, 4
	
	DEC DL
	JNZ .function_arg_loop
	
.function_arg_loop_break:
	CALLA A:B

	MOV J, 0
	SHL I, 2
	ADD SP, J:I
	
	POP C
	DEC C
	JNZ .function_loop
	
.return:
	; re enable cursor blink
	POP AL
	MOV [globals.cursor_enabled], AL

	POP C		; re-enable interrupts
	MOV PF, C
	
	POP J
	POP I
	POP BP
	RET


; function bool make_choice(uint8 choice)
; Makes a choice in the dialog tree. Returns whether the choice was valid
; returns: 1 if a valid choice, 0 otherwise
make_choice:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; get pointer & choice count
	MOVW J:I, [globals.dialog_pointer]
	MOV A, [J:I + 6]
	
	; is choice in range
	MOV B, 0
	MOV BL, [BP + 8]
	CMP AL, BL
	JNA .return
	
	; make choice
	MUL BL, 10
	ADD B, 13		; 7 for choice area, 6 for reference
	MOVW C:D, [J:I + B]
	MOVW [globals.dialog_pointer], C:D
	
	; go to new line
	; diable cursor
	PUSH byte [globals.cursor_enabled]
	MOV A, 0
	MOV [globals.cursor_enabled], AL
	
	MOV A, [globals.cursor_position]
	
	; clear the cursor if is wasnt already
	PUSH A
	PUSH word 0x0020
	CALL txt.func_draw_character
	ADD SP, 2
	POP A
	
	MOV AH, 0
	INC AL
	CMP AL, 30
	JB .dont_scroll
	
	MOV AL, 29
	PUSH A
	
	PUSH byte 1
	CALL txt.func_scroll_screen
	ADD SP, 1
	
	POP A

.dont_scroll:
	MOV [globals.cursor_position], A
	
	; render new page
	CALL render_page
	
	; re-enable cursor
	POP AL
	MOV [globals.cursor_enabled], AL
	
.return:
	POP J
	POP I
	POP BP
	RET
	
	
; function void set_dialog(ptr newpointer)
; Sets the dialog pointer
set_dialog:
	PUSH BP
	MOV BP, SP
	
	MOVW A:B, [BP + 8]
	MOVW [globals.dialog_pointer], A:B

.return:
	POP BP
	RET

goto:
	PUSH BP
	MOV BP, SP
	
	MOVW A:B, [BP + 8]
	MOVW [globals.dialog_pointer], A:B
	
	CALL render_page
	
.return:
	POP BP
	RET


; function void type(ptr dpointer)
; Slowly prints the description of the given dialog pointer
type:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; put description pointer in global
	MOVW A:B, [BP + 8]
	
	MOV D, [A:B]
	MOV [globals.dialog_slow_print_size], D
	MOV I, D
	CMP I, 0
	JE .return
	
	ADD B, 2
	ICC A
	
	MOVW [globals.dialog_slow_print_pointer], A:B
	
	MOVZ D, 0xFF
	MOV [globals.dialog_slow_print_color], DL
	
	MOV D, 1
	MOV [globals.dialog_slow_print_running], DL
	
	; create timers
	MOVW A:B, [globals.global_timer]
	ADD B, SLOW_PRINT_DELAY_TICKS * 2
	ICC A
.timer_loop:
	PUSH ptr slow_print_char
	PUSH A
	PUSH B
	CALL later.set_timer
	POP B
	POP A
	ADD SP, 4
	
	ADD B, SLOW_PRINT_DELAY_TICKS
	ICC A
	
	DEC I
	CMP I, 0xFFFF
	JNE .timer_loop
	
	; wait until we're done printing
.wait_loop:
	CMP byte [globals.dialog_slow_print_running], 0
	JE .return
	
	MOV [0xF000_0000], AL
	JMP .wait_loop

.return:
	; newline 2x combo
	MOV A, 29
	MOV [globals.cursor_position], A
	
	PUSH byte 2
	CALL txt.func_scroll_screen
	ADD SP, 1
	
	POP J
	POP I
	POP BP
	RET


; function void slow_print_char()
; prints 1 character from the slow print string
slow_print_char:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; is there a slow print in progress
	CMP byte [globals.dialog_slow_print_running], 0
	JE .return
	
	; chars left
	MOV A, [globals.dialog_slow_print_size]
	CMP A, 0
	JE .end_print

.print:	
	; print a character
	MOV J:I, [globals.dialog_slow_print_pointer]
	MOV DL, [J:I]
	INC I
	ICC J
	
	; color?
	CMP DL, 0x26
	JNE .dont_change
	
	DEC A
	MOV [globals.dialog_slow_print_size], A
	JZ .end_print
	MOV DL, [J:I]
	INC I
	ICC J
	
	CMP DL, 0x26
	JE .dont_change
	
	CMP DL, 0x41
	JAE .upper_1
	
.lower_1:
	SUB DL, 0x30
	JMP .next_1

.upper_1:
	SUB DL, (0x41 - 10)
	
.next_1:
	MOV DH, DL
	SHL DH, 04
	
	DEC A
	MOV [globals.dialog_slow_print_size], A
	JZ .end_print
	
	MOV DL, [J:I]
	INC I
	ICC J
	
	CMP DL, 0x41
	JAE .upper_2

.lower_2:
	SUB DL, 0x30
	JMP .next_2
	
.upper_2:
	SUB DL, (0x41 - 0x10)
	
.next_2:
	AND DL, 0x0F
	OR DH, DL
	
	MOV [globals.dialog_slow_print_color], DH
	
	DEC A
	JZ .end_print
	MOV DL, [J:I]
	INC I
	ICC J

.dont_change:
	PUSH A
	MOVW [globals.dialog_slow_print_pointer], J:I

	; print the character
	MOV A, [globals.cursor_position]
	PUSH A
	PUSH byte [globals.dialog_slow_print_color]
	PUSH DL
	CALL txt.func_draw_character
	ADD SP, 2
	POP A
	
	INC AH
	
	CMP AH, 40
	JB .dont_wrap
	
	XOR AH, AH
	INC AL
	
	CMP AL, 30
	JB .dont_wrap

.wrap:
	MOV AL, 29
	PUSH byte 1
	CALL txt.func_scroll_screen
	ADD SP, 1

.dont_wrap:
	MOV [globals.cursor_position], A
	
	POP A
	DEC A
	MOV [globals.dialog_slow_print_size], A
	JNZ .return
	
.end_print:
	MOV A, 0
	MOV [globals.dialog_slow_print_running], AL
	
.return:
	POP J
	POP I
	POP BP
	RET