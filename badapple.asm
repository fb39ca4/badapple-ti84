#include "include/app.inc"
#include "include/ti83plus_trimmed.inc"

timerInterval .equ 24
videoInterval .equ 46
musicInterval .equ 75

originalPage .equ lFont_record
currentPage .equ lFont_record + 1
backupA .equ lFont_record + 2
metaTimerCounter .equ lFont_record + 3
videoInterruptCounter .equ lFont_record + 4
trackerInterruptCounter .equ lFont_record + 5
renderBarrier .equ lFont_record + 6

track1Pos .equ $8259
track2Pos .equ $8259 + 2
track3Pos .equ $8259 + 4
track4Pos .equ $8259 + 6

track1Count .equ $8269
track2Count .equ $8269 + 1
track4Count .equ $8269 + 2
track3Count .equ $8269 + 3

frameHeader .equ $83A5 ;MD5Buffer
scanlineHeader .equ $8259 ;MD5Temp

defpage(0, "BadApple")
  di
  ;CPU speed 15Mhz
  ld a, 1
  out ($20), a
  ;turn off auto power down
  res apdAble, (IY+apdFlags) 

  ;copy main loop code to ram so that flash pages can be swapped out
  ld hl, CodeToRamStart
  ld bc, CodeToRamEnd - CodeToRamStart
  ld de, statvars
  ldir

  ;set up interrupt vector table from $9900 to $9A00 to always go to $9A9A
  ld hl, $9900
  ld b, 0
  ld d, $9A
IvtLoop:
  ld (hl), d
  inc hl
  djnz IvtLoop
  ld (hl), d
  
  ;copy interrupt code to $9A9A
  ld hl, InterruptCodeStart
  ld bc, InterruptCodeEnd - InterruptCodeStart
  ld de, $9A9A
  ldir
  
  ;set LCD mode to column auto increment
  ld a, $07
  call LCD_BUSY_QUICK
  out ($10), a
  
  ;save the location of the first page of this app
  in a, ($06)
  ld (OriginalPage), a
  out ($06), a

  ;set timer 1 to 32768Hz
  ld a, $82
  out ($30), a
  ;set timer 1 to loop and interrupt
  ld a, $03
  out ($31), a
  ;set timer 1 count
  ld a, 120
  out ($32), a
  
  ;reset timers 2 and 3
  xor a
  out ($33), a
  out ($34), a
  out ($35), a
  out ($36), a
  out ($37), a
  out ($38), a
  
  ;disable all other interrupts
  ld a, %01000
  out ($03), a
  
  ;zero registers for sound interrupt
  exx
  ld b, 0
  ld c, b
  ld d, b
  ld e, b
  ld h, b
  ld l, b
  exx
  
  ;set tracker counters
  ld hl, track1Count
  ld (hl), 1
  inc hl ;ld hl, track2Count
  ld (hl), 1
  inc hl ;ld hl, track3Count
  ld (hl), 1
  inc hl ;ld hl, track4Count
  ld (hl), 1
  
  ;set tracker positions
  ld hl, Track1Data
  ld (track1Pos), hl
  ld hl, Track2Data
  ld (track3Pos), hl
  ld hl, Track3Data
  ld (track2Pos), hl
  ld hl, Track4Data
  ld (track4Pos), hl
  
  ld a, $99
  ld i, a
  ld hl, VideoStart
  im 2
  ei
  jp statVars

QuitApp:
  di
  ;turn off timers
  xor a
  out ($30), a
  out ($31), a
  out ($32), a
  out ($33), a
  out ($34), a
  out ($35), a
  out ($36), a
  out ($37), a
  out ($38), a
  ;reset link port
  out ($00), a
  ;restore regular interrupts
  ld a, 0
  out ($03), a
  ld a, $0B
  out ($03), a
  ;set LCD to row auto increment
  ld a, $05
  call LCD_BUSY_QUICK
  out ($10), a
  ;set CPU to 6MHz
  ld a, 0
  out ($20), a
  ;statVars was used to store code, so it needs to be invalidated
  b_call _DelRes
  ;enable auto power down
  set apdAble,(IY+apdFlags)
  im 1
  ei
  bjump(_JForceCmdNoChar) 

PageChangeCodeStart:
  ld a, (originalPage)
  dec a
  out ($06), a
  jp statVars
PageChangeCodeEnd:

CodeToRamStart:
PollRenderBarrier:
  ld a, (renderBarrier)
  dec a
  jr nz, PollRenderBarrier
  ld a, 0
  ld (renderBarrier), a
    
SelectFrameType:
  ld b, (hl)
  inc hl
  dec b
  jr z, PFrameJrAssist
  dec b
  jr z, IFrame
  dec b
  jr z, DFrame
  dec b
  jr z, NextPage
  jr NoMoreFrames
  
DFrame: ;duplicated frame, nothing to draw
  jp statvars
  
NextPage: ;go to next page and restart hl from beginning of page
  ld hl, $4000
  in a, ($06)
  dec a
  out ($06), a
  
  jr SelectFrameType
  
NoMoreFrames:
  ld a, (originalPage)
  out ($06), a
  jp QuitApp
  
PFrameJrAssist:
  jr PFrame
  
IFrame: ;draw RLE encoded frame
  ;set LCD to row auto increment
  ld a, $05
  call LCD_BUSY_QUICK
  out ($10), a
  ld c, (hl)
  inc hl
  ;e stores screen row coordinate
  ld e, 12
IColumnLoop:
  ;set LCD to current column
  ld a, $20 + 12
  sub e
  ld d, a ;preserve a
ILCDDelaySetRow:
  in a, ($10)
  rlca
  jr c, ILCDDelaySetRow
  ld a, d ;restore a
  out ($10), a
ILCDDelaySetColumn:
  in a, ($10)
  rlca
  jr c, ILCDDelaySetColumn
  ld a, $80
  ;call LCD_BUSY_QUICK
  out ($10), a
  ld d, 64
IRowLoop:
  ld a, (hl)
  inc hl
  cp c
  jr z, IRepeatStart
  call LCD_BUSY_QUICK
  out ($11), a
IRowLoopEnd
  dec d
  jr nz, IRowLoop
  dec e
  jr nz, IColumnLoop
  jp statvars
IRepeatStart:
  ld b, (hl)
  inc hl
  ld a, (hl)
  inc hl
  jr IRepeatRowLoop
IRepeatColumnLoop:
  ;set LCD to current column
  push af
  ld a, $20 + 12
  sub e
  call LCD_BUSY_QUICK
  out ($10), a
  ld a, $80
  call LCD_BUSY_QUICK
  out ($10), a
  ld d, 64
  pop af
IRepeatRowLoop:
  call LCD_BUSY_QUICK
  out ($11), a
  dec b
  jr z, IRowLoopEnd
  dec d
  jr nz, IRepeatRowLoop
  dec e
  jr nz, IRepeatColumnLoop
  jp statvars
  
PFrame:
  ;set LCD to column auto increment
  ld a, $07
  call LCD_BUSY_QUICK
  out ($10), a
  ;unpack header
  ld ix, frameHeader
  ld d, 8
UnpackFrameHeaderOuterLoop:
  ld b, 8
  ld c, (hl)
  inc hl
UnpackFrameHeaderInnerLoop:
  ld a, c
  rrc c
  and %00000001
  inc a
  ld (ix), a
  inc ix
  djnz UnpackFrameHeaderInnerLoop
  dec d
  jr nz, UnpackFrameHeaderOuterLoop
  ;draw scanlines
  ld e, 64
  ld ix, frameHeader
PRowLoop:
  ld a, (ix)
  inc ix
  dec a
  jr z, PRowLoopEnd
  ;set LCD to current row at first column
SMCInterlaceOffsetB
  ld a, $80 + 64
  sub e
  call LCD_BUSY_QUICK
  out ($10), a
  call LCD_BUSY_QUICK
  ld a, $20
  out ($10), a
PColumn1:
  ;for first 8 columns of LCD
  ld b, 8
  ld c, (hl)
  inc hl
PColumnLoop1:
  rrc c
  jr nc, PSkipByte1
  ld a, (hl)
  inc hl
  ;xor %11111111
  call LCD_BUSY_QUICK
  out ($11), a
PColumnLoopEnd1:  
  djnz PColumnLoop1
  ;last 4 columns
PColumn2:
  ld b, 4
  ld c, (hl)
  inc hl 
PColumnLoop2:
  rrc c
  jr nc, PSkipByte2
  ld a, (hl)
  inc hl
  ;xor %11111111
  call LCD_BUSY_QUICK
  out ($11), a
PColumnLoopEnd2:
  djnz PColumnLoop2
  jr PRowLoopEnd
PSkipByte1
  call LCD_BUSY_QUICK
  in a, ($11)
  jr PColumnLoopEnd1
PSkipByte2:
  call LCD_BUSY_QUICK
  in a, ($11)
  jr PColumnLoopEnd2    
PRowLoopEnd:
  dec e
  jr nz, PRowLoop
  ;b_call _GetKey
  jp statVars
  
Tracker:
  ;ld a, $00;3
  ;out ($37), a
  pop hl
  exx
  ex af, af'
  ei
  push af
  push hl
  in a, ($06)
  ld (currentPage), a
  ld a, (originalPage)
  dec a
  out ($06), a
TrackerCh1:
  ld hl, track1Count
  dec (hl)
  jr nz, TrackerCh2
  di
  exx
  ld d, 1
  exx
  ei
  ld a, %01000111 ;ld b, a
  ld (ch1enabled), a
  ld hl, (track1Pos)
  ld a, (hl)
  inc hl
  ld (track1Count), a
  ld a, (hl)
  inc hl
  ld (ch1fract), a
  ld a, (hl)
  inc hl
  ld (ch1freq), a
  ld (track1Pos), hl
  inc a
  dec a
  jr nz, TrackerCh2
  xor a ;nop
  ld (ch1enabled), a
  ld a, %01
  di
  exx
  and b
  exx
  ei
TrackerCh2:
  in a, ($06)
  dec a
  out ($06), a
  ld hl, track2Count
  dec (hl)
  jr nz, TrackerCh3
  ld a, %01001111 ;ld c, a
  ld (ch2enabled), a
  ld hl, (track2Pos)
  ld a, (hl)
  inc hl
  ld (track2Count), a
  ld a, (hl)
  inc hl
  ld (ch2fract), a
  ld a, (hl)
  inc hl
  ld (ch2freq), a
  ld (track2Pos), hl
  inc a
  dec a
  jr nz, TrackerCh3
  xor a ;nop
  ld (ch2enabled), a
  ld a, %01
  di
  exx
  and c
  exx
  ei
TrackerCh3:
  in a, ($06)
  dec a
  out ($06), a
  ld hl, track3Count
  dec (hl)
  jr nz, TrackerCh4
  di
  exx
  ld e, 1
  exx
  ei
  ld a, %01000111 ;ld b, a
  ld (ch3enabled), a
  ld hl, (track3Pos)
  ld a, (hl)
  inc hl
  ld (track3Count), a
  ld a, (hl)
  inc hl
  ld (ch3fract), a
  ld a, (hl)
  inc hl
  ld (ch3freq), a
  ld (track3Pos), hl
  inc a
  dec a
  jr nz, TrackerCh4
  xor a ;nop
  ld (ch3enabled), a
  ld a, %10
  di
  exx
  and b
  exx
  ei
TrackerCh4:
  in a, ($06)
  dec a
  out ($06), a
  ld hl, track4Count
  dec (hl)
  jr nz, ExitTracker
  ld a, %01001111 ;ld c, a
  ld (ch4enabled), a
  ld hl, (track4Pos)
  ld a, (hl)
  inc hl
  ld (track4Count), a
  inc hl
  ld a, (hl)
  inc hl
  ld (track4Pos), hl
  inc a
  dec a
  jr nz, ExitTracker
  xor a ;nop
  ld (ch4enabled), a
  ld a, %10
  di
  exx
  and c
  exx
  ei
ExitTracker:  
  ld a, (currentPage)
  out ($06), a
  pop hl
  pop af
  ;exx
  ;ex af, af'
  ;ei
  ret
TrackerEnd:
  
UpdateAudio:
  ret
CodeToRamEnd:

InterruptCodeStart:
  di
  ex af, af'
  exx
  ;in a, ($04)
  ;bit 6, a
  ;jr z, VideoCounterTest
Oscillator:
  ld a, $03
  out ($31), a
UpdatePort:
  ld a, b
SMCSound:
  or c
  out ($00), a
  ld a, ($9A9A + SMCSound - InterruptCodeStart)
  xor %00010000
  ld ($9A9A + SMCSound - InterruptCodeStart), a
OscCh1:
  dec d
  jp nz, $9A9A + OscCh2 - InterruptCodeStart
ch1freq .equ $9A9A + $ - InterruptCodeStart + 1  
  ld d, 250
ch1error .equ $9A9A + $ - InterruptCodeStart + 1
  ld a, 0
ch1fract .equ $9A9A + $ - InterruptCodeStart + 1
  add a, 0
  ld (ch1error), a
  jr nc, Ch1NoAdjust
  inc d
Ch1NoAdjust:
  ld a, %10
  xor b
ch1enabled .equ $9A9A + $ - InterruptCodeStart
  ld b, a
OscCh2:
  dec h
  jp nz, $9A9A + OscCh3 - InterruptCodeStart
ch2freq .equ $9A9A + $ - InterruptCodeStart + 1
  ld h, 255
ch2error .equ $9A9A + $ - InterruptCodeStart + 1
  ld a, 0
ch2fract .equ $9A9A + $ - InterruptCodeStart + 1
  add a, 0
  ld (ch2error), a
  jr nc, Ch2NoAdjust
  inc h
Ch2NoAdjust:
ch2FreqHalver .equ $9A9A + $ - InterruptCodeStart + 1
  ld a, %10
  xor c
ch2enabled .equ $9A9A + $ - InterruptCodeStart
  nop;ld c, a
  ld a, (ch2FreqHalver)
  xor %10
  ld (ch2FreqHalver), a
OscCh3:
  dec e
  jp nz, $9A9A + OscCh4 - InterruptCodeStart
ch3freq .equ $9A9A + $ - InterruptCodeStart + 1
  ld e, 255
ch3error .equ $9A9A + $ - InterruptCodeStart + 1
  ld a, 0
ch3fract .equ $9A9A + $ - InterruptCodeStart + 1
  add a, 0
  ld (ch3error), a
  jr nc, Ch3NoAdjust
  inc e
Ch3NoAdjust:
  ld a, %01
  xor b
ch3enabled .equ $9A9A + $ - InterruptCodeStart
  nop;ld b, a
OscCh4:
  dec l
  jp nz, $9A9A + MetaTimer - InterruptCodeStart
ch4freq .equ $9A9A + $ - InterruptCodeStart + 1
  ld l, 3
  ld a, r
  and %1
  xor c
ch4enabled .equ $9A9A + $ - InterruptCodeStart  
  nop;ld c, a


MetaTimer:
  push hl
  ld hl, metaTimerCounter
  dec (hl)
  jr nz, ExitInterrupt
  ld (hl), 24
VideoCounterTest:
  inc hl
  dec (hl)
  jr nz, TrackerCounterTest
  ld a, 1
  ld (renderBarrier), a
  ld (hl), 46
TrackerCounterTest:
  inc hl
  dec (hl)
  jr nz, ExitInterrupt
  ld (hl), 75
  jp statVars + Tracker - CodeToRamStart

ExitInterrupt:
  pop hl
  exx
  ex af, af'
  ei
  ret
InterruptCodeEnd:

VideoStart:
.db 004

.block $8000 - $

defpage(1)
#include "music/track1.asm"
defpage(2)
#include "music/track2.asm"
defpage(3)
#include "music/track3.asm"
defpage(4)
#include "music/track4.asm"
