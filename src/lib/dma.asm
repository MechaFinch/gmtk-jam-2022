
;
; [[ Dynamic Memory Allocator ]]
; Dynamically allocates memory
; Uses an implicit free list aligned to 8 bytes
; Maximum block size 64k
;
; Block Header
; 1 word, exact size except for allocated bit (remember to and with 0xFFFE)
;
; Heap Header
; HEAP_START + 0: pointer to last allocated block
; HEAP_START + 4: pointer to end of heap (value 0)
;
; Constants set for:
;	Heap starting at 0x8000_0000
;
; Note that * is the dereference operator and & is the address operator
;

;
; [ LIBRARY INFO ]
;	Functions
;		void func_init()
;		void* func_malloc(int16 size)
;		void func_free(void* ptr)
;		void* func_realloc(void* ptr, int16 size)
;

; Primary definitions
%define HEAP_START 0x8000_0000

; function void init()
; initializes the heap
func_init:
	; Set HEAP_START + 0 to HEAP_START + 8
	MOVW D:A, HEAP_START + 8
	MOVW [HEAP_START + 0], D:A
	
	; Set HEAP_START + 4 to HEAP_START + 8
	MOVW [HEAP_START + 4], D:A
	
	; Set HEAP_START + 8 to zero
	MOV B, 0x00
	MOVW [D:A], B
	
	RET

; function int16 align(uint16 a)
; aligns a to a multiple of 8
; returns 
func_align:
;	if((a & 0007) == 0) return a
;	else return (a & 0xFFF8) + 8
	PUSH BP
	MOV BP, SP
	
	MOV A, [BP + 8]
	MOV B, A
	AND B, 0x0007
	JZ .return
	
	AND A, 0xFFF8
	ADD A, 0x08
	
.return:
	POP BP
	RET

; function void* malloc(uint16 size)
; allocates size bytes and returns a pointer
func_malloc:
;	uint16 allocSize = align(size + 4);
;	block* current = [HEAP_START];
;	block* lastAllocated = current;
;	block* heapEnd = [HEAP_START + 4];
;
;	uint16 blockHeader;
;	uint16 blockSize;
;
;	while(true) { LOOP ENTERS AT END OF HEAP CHECK BECAUSE FUCK YOU
;		if(current == lastAllocated) { // no valid block found
;			// set block to end of heap and extend it
;			current = heapEnd;
;			blockHeader = allocSize;
;			blockSize = allocSize;
;			
;			[HEAP_START + 4] = current + allocSize;
;			break;
;		} else if(current == heapEnd) { // end of heap
;			current = HEAP_START + 8;
;			continue;
;		}
;
;		// check if this block can work
;		blockHeader = [current];
;		blockSize = blockHeader & 0xFFFE;
;		
;		if((blockHeader & 1) != 0 || blockSize < allocSize) { // allocated or too small
;			// next block
;			current += blockSize;
;		} else {
;			// valid, leave
;			break;
;		}
;	}
;
;	// current now points to the header of the right block and we have its info
;	// split free block if needed
;	if(blockSize > allocSize) {
;		// mark header as correct size
;		uint16 newHeader = allocSize | 1;
;		[current] = newHeader;
;		[current + allocSize - 2] = newHeader; // boundary tag
;
;		// split block
;		blockHeader -= allocSize;
;		[current + allocSize] = blockHeader;
;	} else {
;		// just mark as allocated
;		blockHeader |= 1;
;		[current] = blockHeader;
;		[current + allocSize - 2] = blockHeader; // boundary tag
;	}
;
;	[HEAP_START] = current
;	return current + 2; // returned pointer points to actual contents
;
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; allocate variables
	; J:I = current
	; A = blockHeader
	; B = blockSize
	; D = allocSize
	;
	; BP - 8 = lastAllocated
	; BP - 12 = heapEnd
	SUB SP, 8
	
	; allocSize = align(size + 4)
	MOV A, [BP + 8]
	ADD A, 4
	PUSH A
	CALL func_align
	ADD SP, 2
	MOV D, A
	
	; heapEnd = [HEAP_START + 4]
	MOVW A:B, [HEAP_START + 4]
	MOVW [BP - 12], A:B
	
	; lastAllocated = current = [HEAP_START]
	MOVW A:B, [HEAP_START]
	MOVW J:I, A:B
	MOVW [BP - 8], A:B
	
	JMP .check_heap_end

.main_loop:
	; check if no valid block was found
	CMP I, [BP - 8]
	JNE .check_heap_end
	CMP J, [BP - 6]
	JNE .check_heap_end
	
	; set block to end of heap
	MOVW J:I, [BP - 12]			; current = heapEnd
	
	; extend heap
	MOVW A:B, J:I				; current + allocSize
	ADD B, D
	ICC A
	MOVW [HEAP_START + 4], A:B
	
	MOV A, D					; blockHeader = allocSize
	MOV B, D					; blockSize = allocSize
	JMP .main_loop_end
	
.check_heap_end:
	; did we reach the end of the heap
	CMP I, [BP - 12]
	JNE .check_usable
	CMP J, [BP - 10]
	JNE .check_usable
	
	; loop around
	MOVW J:I, HEAP_START + 8	; current = HEAP_START + 8
	JMP .main_loop

.check_usable:
	; is this block big enough and unallocated
	MOV A, [J:I]				; A = blockHeader = [current]
	MOV B, A					; B = blockSize = blockHeader & 0xFFFE
	AND B, 0xFFFE
	
	MOV C, A					; blockHeader & 1
	AND C, 0x0001
	JNZ .invalid
	
	CMP B, D					; blockSize < allocSize
	JNB .main_loop_end

.invalid:
	; next block
	ADD I, B					; current += blockSize
	ICC J
	JMP .main_loop
	
.main_loop_end:
	; we have a valid block to prepare and return
	CMP B, D					; blockSize > allocSize
	JNA .correct_size
	
	; make correct size header
	MOV C, D					; C = newHeader = allocSize | 1
	OR C, 0x0001
	MOV [J:I], C				; [current] = newHeader
	MOV [J:I + D - 2], C		; [current + allocSize - 2] = newHeader
	
	; split old block
	SUB A, D					; blockHeader -= allocSize
	MOV [J:I + D], A			; [current + allocSize] = blockHeader
	JMP .end

.correct_size:
	; mark as allocated
	OR A, 0x0001				; blockHeader |= 1
	MOV [J:I], A				; [current] = blockHeader
	MOV [J:I + D - 2], A		; [current + allocSize - 2] = blockHeader

.end:
	; mark last allocated
	MOVW [HEAP_START], J:I
	
	; prep return value
	ADD I, 2					; current + 2
	ICC J
	MOVW D:A, J:I
	
	; return
	ADD SP, 8
	POP J
	POP I
	POP BP
	RET
	

; function void free(void* ptr)
; frees the segment at ptr
; ptr points to the data and is what's returned by malloc
func_free:
;	block* block = ptr - 2
;	uint16 blockSize = [block] & 0xFFFE
;	block* nextHTag = block + blockSize
;	block* prevBTag = block - 2
;	uint16 nextHeader = [nextHTag]
;	uint16 prevHeader = [nextHTag]
;
;	// coalesce next?
;	if(nextHeader != 0 && (nextHeader & 1) == 0) {
;		// add tags
;		blockSize += nextHeader;
;	}
;
;	// coalesce previous?
;	if((prevHeader & 1) == 0) {
;		// add tags
;		blockSize += prevHeader;
;
;		// adjust position
;		block -= prevHeader;
;	}
;
;	// set new tags
;	[block] = blockSize;
;	[block + blockSize - 2] = blockSize;
;
	PUSH BP
	MOV BP, SP
	
	; allocate variables
	; J:I = block 
	; D = blockSize
	MOVW J:I, [BP + 8]
	SUB I, 2
	DCC J
	MOV D, [J:I]
	AND D, 0xFFFE
	
	; check next block's header
	MOV A, [J:I + D]			; A = B = nextHeader
	MOV B, A
	
	; nextHeader != 0
	CMP A, 0
	JZ .check_previous
	
	; (nextHeader & 1) == 0
	AND B, 1
	JNZ .check_previous
	
	; blockSize += nextHeader
	ADD D, A

.check_previous:
	; check previous block's header
	MOV A, [J:I - 2]			; A = B = prevHeader
	MOV B, A
	
	; (prevHeader & 1) == 0
	AND B, 1
	JNZ .update_tags
	
	; add & reposition
	ADD D, A					; blockSize += prevHeader
	SUB I, A					; block -= prevHeader
	DCC J

.update_tags:
	; set new tags
	MOV [J:I], D				; [block] = blockSize
	MOV [J:I + D - 2], D		; [block + blockSize - 2] = blockSize
	
	; return
	POP BP
	RET
	

; function void* realloc(void* ptr, uint16 size)
; allocates size bytes, copies min(size, size of ptr) bytes, and returns a pointer
func_realloc:
;	IF THE SIZE IS LESS THAN OR EQUAL TO THE BLOCK
;		Do nothing
;		Eeturn the original pointer
;	IF THE SIZE IS LARGER THAN THE BLOCK
;		If the next block is free and large enough accomodate the reallocation, merge with it.
;		Otherwise, malloc the desired size, copy the data, and free the oroginal block
;		Return the original pointer
;
;	// correct pointer to header
;	ptr -= 2;
;	uint16 blockSize = [ptr] & 0xFFFE;
;	uint16 allocSize = align(size + 4);
;	
;	if(blockSize <= allocSize) return ptr;
;
;	uint16 nextBlockHeader = [ptr + blockSize]
;	uint16 neededSize = allocSize - blockSize;
;	if((nextBlockHeader & 1) == 0 && nextBlockHeader >= neededSize) {
;		// merge with free block
;		uint16 newHeader = allocSize | 1;
;		[ptr] = newHeader;
;		[ptr + allocSize - 2] = newHeader;
;
;		if(neededSize != nextBlockHeader) {
;			// split free block
;			uint16 splitSize = nextBlockHeader - neededSize;
;			[ptr + allocSize] = splitSize;
;			[ptr + allocSize + splitSize - 2] = splitSize;
;		}
;
;		return ptr + 2;
;	} else {
;		// get a new block
;		block* newBlock = malloc(size); // size we got passed
;		memcopy ptr -> newBlock			// fuck you its psuedocode now
;		free(ptr);						// bye bye
;	
;		return newBlock; // doesn't need correction
;	}
	PUSH BP
	MOV BP, SP
	
	PUSH I
	PUSH J
	
	; variables
	; J:I = ptr
	; A = allocSize
	; B = blockSize, neededSize
	; C = nextBlockHeader
	; D = newHeader
	
	; A = allocSize = align(size + 4)
	PUSH word [BP + 12]
	ADD word [SP], 0x0004
	CALL func_align
	ADD SP, 2
	
	; B = blockSize = [ptr] & 0xFFFE
	MOVW J:I, [BP + 8]
	SUB I, 2
	DCC J
	MOV B, [J:I]
	AND B, 0xFFFE
	
	; if(blockSize <= allocSize) return ptr
	CMP B, A
	JBE .return_ptr

.larger:
	; C = nextBlockHeader = [ptr + blockSize]
	; B = neededSize = allocSize - blockSize
	MOV C, [J:I + B]
	NEG B
	ADD B, A
	
	; if((nextBlockHeader & 1) == 0 && nextBlockHeader >= neededSize)
	CMP C, B
	JNAE .get_new
	MOV D, C
	AND D, 1
	JNZ .get_new
	
	; merge with free block
	; D = newHeader = allocSize | 1
	MOV D, A
	OR D, 1
	
	; [ptr] = newHeader
	; [ptr + allocSize - 2] = newHeader
	MOV [J:I], D
	MOV [J:I + A - 2], D
	
	; if(neededSize != newBlockHeader)
	CMP B, C
	JE .return_ptr
	
	; split free block
	; C = splitSize = nextBlockHeader - neededSize
	; [ptr + allocSize] = splitSize
	; [ptr + allocSize + splitSize - 2] = splitSize
	SUB C, B
	MOV [J:I + A], C
	ADD A, C
	SUB A, 2 ; here instead of addressing saves 2 bytea
	MOV [J:I + A], C

.return_ptr:
	; return whatever pointer's in J:I
	ADD I, 2
	ICC J
	MOVW D:A, J:I
	POP J
	POP I
	POP BP
	RET

.get_new:
	; find A = (min(blockSize, allocSize) - 8) >> 2
	; size - 8 points to the last 4 bytes of a block
	; that >> 2 lets us count by 4s
	; no information is lost because sizes are multiples of 8
	CMP B, A
	JAE .get_new_next
	MOV A, B
	
.get_new_next:
	SUB A, 8
	SHR A, 2
	PUSH A ; save

	; get new block
	; D:A = newBlock = malloc(size)
	PUSH word [BP + 12]
	CALL func_malloc
	ADD SP, 2
	
	; copy from old to new
	; copy min(blockSize - 4, allocSize - 4) bytes from starting at (ptr + 2) to starting at (newBlock)
	POP C ; min(blockSize - 4, allocSize - 4)
	; [user pointer + C] = end header
	
	; save ptr and newBlock
	PUSH A
	PUSH D
	PUSH J
	PUSH I
	
	; setup J:I = source and BP = destination (so we can transfer 4 bytes at a time)
	ADD I, 2
	ICC J
	MOVW BP, D:A
.copy_loop:
	; end on wrap around
	CMP C, 0xFFFF
	JE .copy_break
	
	; transfer
	MOVW D:A, [J:I + 4*C]
	MOVW [BP + 4*C], D:A
	
	DEC C
	JMP .copy_loop
.copy_break:
	
	; free old (ptr was already pushed)
	CALL func_free
	ADD SP, 4
	
	; return newBlock
	POP D
	POP A
	POP J
	POP I
	POP BP
	RET