	.nolist

#define bcall(xxxx)	rst 28h \ .dw xxxx
.addinstr B_CALL *       EF   3 NOP 1
#define bjump(label) call 50h \ .dw label

usermemoff        = $89EC
_JForceCmd        = $402A
_homeup           = $4558
LCD_BUSY_QUICK	= $000B

lFont_record         .equ  845Ah
apdFlags	.equ  8		;Automatic power-down
apdAble 	.equ    2	; 1=APD enabled
statVars             .equ  8A3Ah


_DelRes		.equ 4A20h
_JForceCmdNoChar	.equ 4027h
