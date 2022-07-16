
;
; [[ Interrupt Handlers ]]
; functions that handle interrupts
;
; update_clock updates the internal clock
; keyboard_input handles keyboard input
;

%libname handlers
%include globals.asm as globals
%include runlater.asm as later
%include "lib/text.asm" as txt

%define CURSOR_PERIOD 5
%define CURSOR_COLOR 0xFF

; update global timer
; updates the global timer
update_global_timer:
	PUSHA
	
	MOVW J:I, [globals.global_timer]
	INC I
	ICC J
	MOVW [globals.global_timer], J:I
	
	; runlater hook
	CALL later.hook
	
	; toggle cursor if applicible
	MOV B, I
	DIVM B, CURSOR_PERIOD
	
	CMP BH, 0
	JNE .dont_toggle
	
	CMP byte [globals.cursor_state], 0
	JNE .toggle_cursor_off

.toggle_cursor_on:
	PUSH word [globals.cursor_position]
	PUSH byte CURSOR_COLOR
	PUSH byte 0x5F
	CALL txt.func_draw_character
	ADD SP, 4
	
	MOV A, 1
	MOV [globals.cursor_state], AL
	JMP .dont_toggle
	
.toggle_cursor_off:
	PUSH word [globals.cursor_position]
	PUSH byte CURSOR_COLOR
	PUSH byte 0x20
	CALL txt.func_draw_character
	ADD SP, 4
	
	MOV A, 0
	MOV [globals.cursor_state], AL
	
.dont_toggle:
	POPA
	IRET
	

; keyboard input
; handle key presses
keyboard_input:
	PUSHA
	
	
	
	POPA
	IRET