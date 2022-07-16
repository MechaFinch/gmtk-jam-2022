
;
; [[ Tree Walker ]]
; navigates the dialog tree
;
; [ INFO ]
;	Functions
;		void render_page()
;		bool make_choice(uint8 choice)
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

%libname dtree
%include "lib/text.asm" as txt
%include globals.asm as globals
%include runlater.asm as later

%define DESCRIPTION_START_ROW 1
%define DESCRIPTION_START_COL 0
%define DESCRIPTION_COLOR 0xFF
%define CHOICE_START_ROW (30 - 9)
%define CHOICE_START_COL 1
%define CHOICE_COLOR 0xFF
%define CHOICE_ERROR_START 0x011D
%define CHOICE_ERROR_COLOR 0b111_001_01
%define ERROR_TIME 20


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
	
	; get pointer
	MOVW J:I, [globals.dialog_pointer]
	
	; print description
	PUSH word ((DESCRIPTION_START_COL * 256) + DESCRIPTION_START_ROW)
	PUSH byte DESCRIPTION_COLOR
	PUSH word [J:I]
	PUSH word [J:I + 4]
	PUSH word [J:I + 2]
	CALL txt.func_print_string
	ADD SP, 9
	
	; print choices
	MOV D, ((CHOICE_START_COL * 256) + CHOICE_START_ROW)
	MOV C, 0
	MOV CL, [J:I + 6]
	ADD I, 7
	ICC J
.choice_loop:
	PUSH C
	
	PUSH D
	PUSH byte CHOICE_COLOR
	PUSH word [J:I + 0]
	PUSH word [J:I + 4]
	PUSH word [J:I + 2]
	CALL txt.func_print_string
	ADD SP, 7
	POP D
	POP C
	
	; increment row
	INC DL
	
	; increment choice index
	ADD I, 10
	ICC J
	
	; loop
	DEC C
	JNZ .choice_loop
	
	; call functions
	MOV C, 0
	MOV CL, [J:I]
	CMP CL, 0
	JE .return
	INC I
	ICC J
	
.function_loop:
	PUSH C
	
	MOVW A:B, [J:I]
	CALL A:B
	
	POP C
	INC I
	ICC J
	DEC C
	JNZ .function_loop
	
.return:
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
	
.return:
	POP J
	POP I
	POP BP
	RET


; function void write_error()
; Writes an "invalid choice" error message to the bottom of the screen
write_error:
	PUSH BP
	MOV BP, SP
	
	; write message
	PUSH word CHOICE_ERROR_START
	PUSH byte CHOICE_ERROR_COLOR
	PUSH word (error_message_end - error_message)
	PUSH ptr error_message
	CALL txt.func_print_string
	ADD SP, 9
	
	; create erase callback
	MOVW A:B, [globals.global_timer]
	ADD B, ERROR_TIME
	ICC A
	
	PUSH clear_error
	PUSH A:B
	CALL later.set_timer
	ADD SP, 8

.return:
	POP BP
	RET


; function void clear_error()
; Clears the "invalid choice" error message
clear_error:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	
	; clear error message
	MOV A, CHOICE_ERROR_START
	MOV B, 0x0020
	PUSH A:B
	
	MOV I, (error_message_end - error_message)
.loop:
	CALL txt.func_draw_character
	DEC I
	JNZ .loop
	
	ADD SP, 4
	
.return:
	POP I
	POP BP
	RET


; data
error_message:	db "invalid choice"
error_message_end: