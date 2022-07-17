
; 
; [[ Main ]]
; initialize environment
;

%libname init
%include interrupt_handlers.asm as handlers
%include tree_walker.asm as dtree
%include dialog.obj as dialog
%include "lib/dma.asm" as mem
%include globals.asm as globals
%include game_logic.asm as logic
%include constants.asm as constants

main:
	; init memory allocator
	CALL mem.func_init

	; set interrupt 1 to update global timer
	MOVW A:B, handlers.update_global_timer
	MOVW [0x0000_0004], A:B
	
	; set interrupt 2 to handle keyboard input
	MOVW A:B, handlers.keyboard_input
	MOVW [0x0000_0008], A:B
	
	; setup globals
	; global timer
	MOVZ A:B, 0
	MOVW [globals.global_timer], A:B
	
	; dialog tree root
	MOVW A:B, dialog.root
	MOVW [globals.dialog_pointer], A:B
	
	; enable dialog choices
	MOV A, 1
	MOV [globals.dialog_can_make_choice], AL
	
	; runlater array
	PUSH word 16
	CALL mem.func_malloc
	ADD SP, 2
	
	MOVW [globals.runlater_pointer], D:A
	MOV A, 2
	MOV [globals.runlater_size], A
	
	; enable cursor
	MOV A, 1
	MOV [globals.cursor_enabled], AL
	
	; start cursor at bottom of screen
	MOV A, 29
	MOV [globals.cursor_position], A
	
.start:
	; render first dialog page
	CALL dtree.render_page
	
.wait:
	; wait for interrupts
	MOV [0xF000_0000], AL
	JMP .wait