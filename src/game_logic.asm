
;
; [[ Game Logic ]]
; handles game logic
; aaaaaaaaaaaaaaaaaaaaaaaaaaa
;
;	Functions
;		void set_flag_true(ptr flag)
;		void set_flag_false(ptr flag)
;		void goto_conditional(ptr flag, ptr true_node, ptr false_node)
;

%libname logic
%include globals.asm as globals
%include flags.asm as flags
%include tree_walker.asm as dtree
%include dialog.obj as dialog

; function void set_flag_true(ptr flag)
; sets the given flag true
set_flag_true:
	PUSH BP
	MOV BP, SP
	
	MOVW A:B, [BP + 8]
	MOV C, 1
	MOV [A:B], CL
	
.return:
	POP BP
	RET


; function void set_flag_false(ptr flag)
; sets the given flag false
set_flag_false:
	PUSH BP
	MOV BP, SP
	
	MOVW A:B, [BP + 8]
	MOV C, 0
	MOV [A:B], CL
	
.return:
	POP BP
	RET


; function void goto_conditional(ptr flag, ptr true_node, ptr false_node)
goto_conditional:
	PUSH BP
	MOV BP, SP
	
	MOVW A:B, [BP + 8]
	CMP byte [A:B], 0
	JE .false

.true:
	MOVW A:B, [BP + 12]
	MOVW [globals.dialog_pointer], A:B
	JMP .render

.false:
	MOVW A:B, [BP + 16]
	MOVW [globals.dialog_pointer], A:B
	
.render:
	CALL dtree.render_page
	
.return:
	POP BP
	RET


goto_end:
	MOVW A:B, dialog.roll_the_dice
	MOVW [globals.dialog_pointer], A:B
	CALL dtree.render_page
	
.end:
	MOV [0xF000_0000], AL
	JMP .end
	RET

estimate_time:
	MOVW C:D, [globals.global_timer]
	
	MOVW A:B, (10 * 60 * 20)
	;SUB B, D
	;SBB A, C
	
	DIVM A:B, word 60 ; A = seconds B = minutes
	
	DIVM A, byte 10 ;AH = tens AL = ones
	DIVM B, byte 10
	
	ADD AL, 0x30
	ADD AH, 0x30
	ADD BL, 0x30
	ADD BH, 0x30
	
	MOV C, 2
	MOV [globals.time_left_string + C], BH
	INC C
	MOV [globals.time_left_string + C], BL
	ADD C, 2
	MOV [globals.time_left_string + C], AH
	INC C
	MOV [globals.time_left_string + C], AL
	
	PUSH ptr globals.time_left_string
	CALL dtree.type
	ADD SP, 4
	RET


set_forward_active:
	MOV A, 1
	MOV [flags.forward_active], AL
	RET

clear_forward_active:
	MOV A, 0
	MOV [flags.forward_active], AL
	RET
	
set_backward_active:
	MOV A, 1
	MOV [flags.backward_active], AL
	RET

clear_backward_active:
	MOV A, 0
	MOV [flags.backward_active], AL
	RET

clear_thrusters_activated:
	MOV A, 0
	MOV [flags.thrusters_activated], AL
	RET





; flag setters
set_diagnostics_run:
	MOV A, 1
	MOV [flags.diagnostics_run], AL
	RET

set_power_diagnostic:
	MOV A, 1
	MOV [flags.power_diagnostic], AL
	RET

set_altimetry_diagnostic:
	MOV A, 1
	MOV [flags.altimetry_diagnostic], AL
	RET

set_sensors_diagnostic:
	MOV A, 1
	MOV [flags.sensors_diagnostic], AL
	RET

set_sensors_activated:
	MOV A, 1
	MOV [flags.sensors_activated], AL
	RET

set_thrusters_diagnostic:
	MOV A, 1
	MOV [flags.thrusters_diagnostic], AL
	RET

set_thrusters_activated:
	MOV A, 1
	MOV [flags.thrusters_activated], AL
	RET

set_radio_send_1:
	MOV A, 1
	MOV [flags.radio_send_1], AL
	RET

set_radio_send_2:
	MOV A, 1
	MOV [flags.radio_send_2], AL
	RET

set_radio_send_3:
	MOV A, 1
	MOV [flags.radio_send_3], AL
	RET

set_radio_send_4:
	MOV A, 1
	MOV [flags.radio_send_4], AL
	RET

set_thruster_toosoon:
	MOV A, 1
	MOV [flags.thruster_toosoon], AL
	RET

set_thruster_ok:
	MOV A, 1
	MOV [flags.thruster_ok], AL
	RET

set_thruster_snakeeyes:
	MOV A, 1
	MOV [flags.thruster_snakeeyes], AL