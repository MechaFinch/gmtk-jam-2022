
;
; [[ Run Later ]]
; Manages the run later system
;
; [ INFO ]
;	Functions
;		void set_timer(uint32 time, ptr func)
;
;	Interrupt Handlers
;		hook
;

%libname later
%include "lib/dma.asm" as mem
%include globals.asm as globals

; hook
; called by the global timer every tick
hook:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; if runlater is busy (the global timer updated during a realloc or something)
	; skip the hook
	CMP byte [globals.runlater_operating], 0
	JNZ .return
	
	; for each entry in the runlater array, check if the timer is >= their time
	; if the time has been met, remove the entry and call the function
	; remember to re-load the array pointer after each call
	MOV A:B, [globals.runlater_pointer]
	MOV I, [globals.runlater_size]
.loop:
	; get & compare entry time
	MOV C:D, [A:B + I*8 + 0]
	
	CMP C, 0
	JNE .check
	CMP D, 0
	JE .next

.check:
	MOV A:B, globals.global_timer
	
	CMP C, [A:B + 2]
	JA .next
	
	CMP D, [A:B + 0]
	JA .next
	
	; remove entry
	MOV A:B, [globals.runlater_pointer]
	MOV C, 0
	MOVZ [A:B + I*8], C
	
	; call function
	MOV C:D, [A:B + I*8 + 4]
	CALLA C:D

.next:
	MOV A:B, [globals.runlater_pointer]
	DEC I
	JNZ .loop
	
.return:
	POP J
	POP I
	POP BP
	RET


; function void set_timer(uint32 time, ptr func)
; Sets a function to be run at the given time
set_timer:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; for each entry in the runlater array, check for an empty spot.
	; if a free spot is found, use it
	; otherwise, realloc the array and use the new spot	
	MOVW A:B, [globals.runlater_pointer]
	MOV I, [globals.runlater_size]
	DEC I
	
.loop:
	MOV C:D, [A:B + I*8 + 0]
	CMP C, 0
	JNE .next
	CMP D, 0
	JNE .next
	
	; found one, use it
	MOVW C:D, [BP + 8]
	MOVW [A:B + I*8 + 0], C:D
	MOVW C:D, [BP + 12]
	MOVW [A:B + I*8 + 4], C:D
	JMP .return

.next:
	MOV A:B, [globals.runlater_pointer]
	
	CMP I, 0
	JE .not_found
	DEC I
	JMP .loop

.not_found:
	; realloc array
	MOV C, 1
	MOV [globals.runlater_operating], CL
	
	MOV C, [globals.runlater_size]
	INC C
	MOV [globals.runlater_size], C
	PUSH C
	SHL C, 3
	
	PUSH C
	PUSH A
	PUSH B
	CALL mem.func_realloc
	ADD SP, 6
	
	MOVW [globals.runlater_pointer], D:A
	
	; use new spot
.use:
	POP I
	DEC I
	MOVW B:C, [BP + 8]
	MOVW [D:A + I*8 + 0], B:C
	MOVW B:C, [BP + 12]
	MOVW [D:A + I*8 + 4], B:C
	
	MOV C, 0
	MOV [globals.runlater_operating], CL

.return:
	POP J
	POP I
	POP BP
	RET


; function void set_timer_var(ptr variable, ptr function)
; sets the function to run at (global timer) + (the time at the variable)
set_timer_var:
	PUSH BP
	MOV BP, SP
	
	MOV C, 2
	MOVW A:B, [BP + 8]
	MOVW A:B, [A:B]
	ADD B, [globals.global_timer]
	ADC A, [globals.global_timer + C]
	
	PUSH word [BP + 14]
	PUSH word [BP + 12]
	PUSH A
	PUSH B
	CALL set_timer
	ADD SP, 8
	
	POP BP
	RET