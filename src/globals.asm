
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
cursor_position:				resb 2
cursor_state:					resb 1