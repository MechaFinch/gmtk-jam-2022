
;
; [[ Globals ]]
; globals :)
;

%libname globals

global_timer:					resb 4	; global timer
runlater_pointer:				resb 4	; points to the runlater array
runlater_size:					resb 2
runlater_operating:				resb 1	; boolean for whether runlater is busy
dialog_pointer:					resb 4	; points to the header of the current dialog node
dialog_can_make_choice:			resb 1
dialog_slow_print_running:		resb 1
dialog_slow_print_size:			resb 2  ; number of characters left to slow-print
dialog_slow_print_pointer:		resb 4	; string pointer for slow printing
dialog_slow_print_color:		resb 1
cursor_position:				resb 2	; col:row
cursor_state:					resb 1
cursor_enabled:					resb 1
time_left_string:				dw 5
								db "??:??"