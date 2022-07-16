

;
; [[ Util ]]
; Some utilities
;
; [ LIBRARY INFO ]
;	Functions
;		uint32 func_to_hex_string(uint16 num)
;		void print_i32(uint32 dat)
;

%include text.asm as txt

; function uint32 to_hex_string(uint16 num)
; Converts the given number to a hex string, returned as an int
func_to_hex_string:
	PUSH BP
	MOV BP, SP
	
	MOV D, [BP + 8]
	MOV CL, DL
	AND CL, 0x0F
	CALL .sub_to_char
	MOV AL, CL
	
	MOV CL, DL
	SHR CL, 4
	CALL .sub_to_char
	MOV AH, CL
	
	MOV CL, DH
	AND CL, 0x0F
	CALL .sub_to_char
	MOV DL, CL
	
	MOV CL, DH
	SHR CL, 4
	CALL .sub_to_char
	MOV DH, CL

.return:
	POP BP
	RET

.sub_to_char:
	; convert CL to its character
	CMP CL, 0x0A
	JB .lower

.upper:
	ADD CL, 0x41 - 0x0A
	RET

.lower:
	ADD CL, 0x30
	RET


; function void print_i32(uint32 dat, uint8 color, uint8 row, uint8 col)
; Prints the 4 characters given. Assumes there is enough space on screen.
func_print_i32:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	
	MOV I, [BP + 13] ; col:row
	
	PUSH I
	PUSH word [BP + 11]
	CALL txt.func_draw_character
	ADD SP, 4
	ADD I, 0x0100
	
	PUSH I
	PUSH byte [BP + 12] ; color
	PUSH byte [BP + 10]	; char
	CALL txt.func_draw_character
	ADD SP, 4
	ADD I, 0x0100
	
	PUSH I
	PUSH byte [BP + 12] ; color
	PUSH byte [BP + 9]	; char
	CALL txt.func_draw_character
	ADD SP, 4
	ADD I, 0x0100
	
	PUSH I
	PUSH byte [BP + 12] ; color
	PUSH byte [BP + 8]	; char
	CALL txt.func_draw_character
	ADD SP, 4
	
.return:
	POP I
	POP BP
	RET