
;
; [[ Text ]]
; Draws text to the screen
;
; [ LIBRARY INFO ]
;	Functions
;		void func_draw_character(uint8 char, uint8 color, uint8 row, uint8 col)
;		uin16 func_print_string(uint8* string, uint16 length, uint8 color, uint8 row, uint8 column)
;		void func_scroll_screen(sint8 rows)
;		void func_clear_screen()
;

%libname text

%define SCREEN_WIDTH 320
%define SCREEN_HEIGHT 240
%define SCREEN 0xC000_0000
%define CHARACTER_SET 0xC001_3000
%define CHARACTER_SIZE_PIXELS 8
%define CHARACTER_SIZE_BYTES 32

%define SCREEN_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT)
%define SCREEN_WIDTH_CHARACTERS (SCREEN_WIDTH / CHARACTER_SIZE_PIXELS)
%define SCREEN_HEIGHT_CHARACTERS (SCREEN_HEIGHT / CHARACTER_SIZE_PIXELS)

; function void draw_character(uint8 char, uint8 color, uint8 row, uint8 col)
; draws the given character to the screen in the given color
func_draw_character:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; AB 	data
	; C 	color mask
	; D		counter
	; JI	source pointer
	; BP 	destination pointer
	
	; character address = CHARACTER_SET + (char * CHARACTER_SIZE_BYTES)
	; screen address = SCREEN + (row * SCREEN_WIDTH) + (column * CHARACTER_SIZE_PIXELS)
	
	; AL = char, AH = col
	; CL = color, CH = color
	; BL = row, BH = color
	MOVW A:B, [BP + 8]
	MOV CH, BH
	MOV CL, BH
	XCHG AL, BL	
	
	; multiply col * CHARACTER_SIZE_PIXELS and char * CHARACTER_SIZE_BYTES
	; A = char * CHARACTER_SIZE_BYTES
	; D = col * CHARACTER_SIZE_PIXELS
	PMULH8 D:A, (CHARACTER_SIZE_PIXELS * 0x0100) + CHARACTER_SIZE_BYTES
	XCHG AH, DL
	
	; JI = source pointer
	MOVW J:I, CHARACTER_SET
	ADD I, A
	ICC J
	
	; BP = destination pointer
	MOVW BP, SCREEN
	MOV A, D
	MOV D, 0
	ADD BP, D:A		; col * CHARACTER_SIZE_PIXELS
	
	; multiply row * SCREEN_WIDTH * CHARACTER_SIZE_PIXELS
	MOVZ A, BL
	MULH D:A, (SCREEN_WIDTH * CHARACTER_SIZE_PIXELS)
	
	ADD BP, D:A		; row * SCREEN_WIDTH * CHARACTER_SIZE_PIXELS
	
	; draw line by line
	MOV D, 8
.draw_loop:
	; for each half line, get 2 bytes, split them up, multiply by color mask, then put them on screen
	; first half line
	MOV B, [J:I]
	MOV A, B
	
	AND B, 0x1010
	SHR B, 4
	AND A, 0x0101
	XCHG BH, AL
	
	PMUL8 B, C
	PMUL8 A, C
	
	MOVW [BP], A:B
	
	; increment source & dest
	ADD I, 2
	ICC J
	ADD BP, 4
	
	; second half line
	MOV B, [J:I]
	MOV A, B
	
	AND B, 0x1010
	SHR B, 4
	AND A, 0x0101
	XCHG BH, AL
	
	PMUL8 B, C
	PMUL8 A, C
	
	MOVW [BP], A:B
	
	; increment for next line
	ADD I, 2
	ICC J
	ADD BP, SCREEN_WIDTH - 4
	
	; loop
	DEC D
	JNZ .draw_loop

.return:
	POP J
	POP I
	POP BP
	RET


; function uint16 print_string(uint8* string, uint16 length, uint8 color, uint8 row, uint8 column)
; draws a string starting at (row, column)
; returns the position of the cursor as column:row
func_print_string:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; J:I	string pointer
	; AH	col
	; AL	row
	; DH	color
	; DL	char
	; C		counter
	
	MOVW J:I, [BP + 8]	; string
	MOV C, [BP + 12]	; length
	MOV DH, [BP + 14]	; color
	MOV A, [BP + 15]	; column:row
	
.print_loop:
	; get character
	MOV DL, [J:I]
	INC I
	ICC J
	
	; newlines are newlines
	CMP DL, 0x0A
	JE .wrap
	
	; draw character
	PUSH A
	PUSH B
	PUSH C
	PUSH D
	
	PUSH A
	PUSH D
	CALL func_draw_character
	ADD SP, 4
	
	POP D
	POP C
	POP B
	POP A
	
	; increment column
	INC AH
	
	; wrap if needed
	CMP AH, SCREEN_WIDTH_CHARACTERS
	JB .print_loop_next
	
.wrap:
	XOR AH, AH
	INC AL
	
	; scroll screen if needed
	CMP AL, SCREEN_HEIGHT_CHARACTERS
	JL .print_loop_next
	
	; scroll screen
	PUSH A
	PUSH B
	PUSH C
	PUSH D
	
	PUSH byte 1
	CALL func_scroll_screen
	ADD SP, 1
	
	POP D
	POP C
	POP B
	POP A
	
	MOV AL, SCREEN_HEIGHT_CHARACTERS - 1
	
.print_loop_next:
	; just loop
	DEC C
	JNZ .print_loop
	
.return:
	POP J
	POP I
	POP BP
	RET
	

; function uint16 print_colored_string(uint8* string, uint16 length, uint8 color, uint8 row, uint8 column)
; draws a string starting at (row, column)
; respects &<color number> in the text for changing current color
; returns the position of the cursor as column:row
func_print_string_colored:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; J:I	string pointer
	; AH	col
	; AL	row
	; DH	color
	; DL	char
	; C		counter
	
	MOVW J:I, [BP + 8]	; string
	MOV C, [BP + 12]	; length
	MOV DH, [BP + 14]	; color
	MOV A, [BP + 15]	; column:row
	
.print_loop:
	; get character
	MOV DL, [J:I]
	INC I
	ICC J
	
	; newlines are newlines
	CMP DL, 0x0A
	JE .wrap
	
	; ampersand sets color
	CMP DL, 0x26
	JNE .dont_change
	
	; get next character
	DEC C
	JZ .return
	MOV DL, [J:I]
	INC I
	ICC J
	
	; if ampersand, it's not color
	CMP DL, 0x26
	JE .dont_change
	
	; convert to upper half byte
	CMP DL, 0x41
	JAE .high_1
	
.low_1:
	SUB DL, 0x30
	JMP .lower_char

.high_1:
	SUB DL, (0x41 - 10)
	
.lower_char:
	SHL DL, 4
	MOV DH, DL

	; other char
	DEC C
	JZ .return
	MOV DL, [J:I]
	INC I
	ICC J
	
	CMP DL, 0x41
	JAE .high_2

.low_2:
	SUB DL, 0x30
	JMP .make_num

.high_2:
	SUB DL, (0x41 - 10)
	
.make_num:
	AND DL, 0x0F
	OR DH, DL
	JMP .print_loop_next

.dont_change:
	; draw character
	PUSH A
	PUSH B
	PUSH C
	PUSH D
	
	PUSH A
	PUSH D
	CALL func_draw_character
	ADD SP, 4
	
	POP D
	POP C
	POP B
	POP A
	
	; increment column
	INC AH
	
	; wrap if needed
	CMP AH, SCREEN_WIDTH_CHARACTERS
	JB .print_loop_next
	
.wrap:
	XOR AH, AH
	INC AL
	
	; scroll screen if needed
	CMP AL, SCREEN_HEIGHT_CHARACTERS
	JL .print_loop_next
	
	; scroll screen
	PUSH A
	PUSH B
	PUSH C
	PUSH D
	
	PUSH byte 1
	CALL func_scroll_screen
	ADD SP, 1
	
	POP D
	POP C
	POP B
	POP A
	
	MOV AL, SCREEN_HEIGHT_CHARACTERS - 1
	
.print_loop_next:
	; just loop
	DEC C
	JNZ .print_loop
	
.return:
	POP J
	POP I
	POP BP
	RET


; function void scroll_screen(sint8 rows)
; scrolls the screen up by the given number of rows
func_scroll_screen:
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; up or down?
	MOVS A, byte [BP + 8]
	CMP A, 0
	JE .return
	JB .scroll_down_start
	
.scroll_up_start:
	CMP A, SCREEN_HEIGHT_CHARACTERS
	JGE .clear_screen
	
	; move from high to low index, incrementing indicies
	MUL A, (SCREEN_WIDTH / 4) * CHARACTER_SIZE_PIXELS; distance
	MOV I, A
	MOV J, 0
	MOV BP, SCREEN
	
	; copy through C:D until the end of the screen
.scroll_up:
	; we do a little unrolling
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	INC I
	INC J
	
	CMP I, SCREEN_SIZE / 4
	JB .scroll_up
	
	; clear bottom of screen
	MOVZ C:D, 0
.clear_bottom:
	MOVW [SCREEN + J*4], C:D
	INC J
	MOVW [SCREEN + J*4], C:D
	INC J
	MOVW [SCREEN + J*4], C:D
	INC J
	MOVW [SCREEN + J*4], C:D
	INC J
	
	MOVW [SCREEN + J*4], C:D
	INC J
	MOVW [SCREEN + J*4], C:D
	INC J
	MOVW [SCREEN + J*4], C:D
	INC J
	MOVW [SCREEN + J*4], C:D
	INC J
	
	CMP I, J ; we left I at the end, shortcut
	JNE .clear_bottom
	JMP .return

.scroll_down_start:
	; negate scroll distance
	NEG A
	
	CMP A, SCREEN_HEIGHT
	JAE .clear_screen
	
	; low to high index, decrement indicies
	MUL A, (SCREEN_WIDTH / 4) * CHARACTER_SIZE_PIXELS
	MOV J, (SCREEN_SIZE / 4) - 1
	MOV I, J
	SUB I, A
	MOV BP, SCREEN
	
	; copy until the start
.scroll_down:
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	MOVW C:D, [BP + I*4]
	MOVW [BP + J*4], C:D
	DEC J
	DEC I
	
	CMP I, 0
	JL .scroll_down
	
	; clear top
	MOVZ C:D, 0
.clear_top:
	MOVW [BP + J*4], C:D
	DEC J
	MOVW [BP + J*4], C:D
	DEC J
	MOVW [BP + J*4], C:D
	DEC J
	MOVW [BP + J*4], C:D
	DEC J
	
	MOVW [BP + J*4], C:D
	DEC J
	MOVW [BP + J*4], C:D
	DEC J
	MOVW [BP + J*4], C:D
	DEC J
	MOVW [BP + J*4], C:D
	DEC J
	
	CMP J, 0
	JGE .clear_top
	JMP .return

.clear_screen:
	CALL func_clear_screen
	
.return:
	POP J
	POP I
	POP BP
	RET

; function void clear_screen
; clears the screen
func_clear_screen:
	PUSH BP
	PUSH I
	
	MOVZ C:D, 0
	MOV I, 0
	MOV BP, SCREEN
	
.loop:
	; a spoonfull of unrolling
	; clears 64 bytes at a time
	MOVW [BP + I*4], C:D
	INC I
	MOVW [BP + I*4], C:D
	INC I
	MOVW [BP + I*4], C:D
	INC I
	MOVW [BP + I*4], C:D
	INC I
	
	MOVW [BP + I*4], C:D
	INC I
	MOVW [BP + I*4], C:D
	INC I
	MOVW [BP + I*4], C:D
	INC I
	MOVW [BP + I*4], C:D
	INC I
	
	CMP I, SCREEN_SIZE / 4
	JL .loop

.return:
	POP I
	POP BP
	RET