

; scratch file

%libname test
%include "lib/text.asm" as txt

main:
	MOVW A:B, interrupt
	MOV [0x0000_0004], A:B
	MOV [0x0000_0008], A:B

	MOV A, 0x0000
	MOV B, 0x0023

.loop:
	PUSH A
	PUSH B
	CALL txt.func_draw_character
	POP B
	POP A
	
	INC AH
	CMP AH, 40
	JL .skip
	
	MOV AH, 0
	INC AL

.skip:
	INC BH
	JNZ .loop
	
.halt:
	MOV [0xF000_0000], AL
	JMP .halt
	

interrupt:
	IRET