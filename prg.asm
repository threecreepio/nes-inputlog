; tell the compiler that this code will be loaded at memory address $8000 in the NES
.org $8000

; see https://wiki.nesdev.com/w/index.php/PPU_registers
PPUCTRL               = $2000
PPUMASK               = $2001
PPUSTATUS             = $2002
PPUSCROLL             = $2005
PPUADDR               = $2006
PPUDATA               = $2007
OAMDMA                = $4014
JOYPAD_PORT           = $4016

; some ram addresses used by our program
HeldButtons = $0C
Procedure     = $7FF
ProcedureAddr = $7FD

; this code will run at startup, or when reset is pressed.
BOOT:
    ; enable interrupts
    sei
    cld
    ; clear the stack
    ldx #$FF
    txs
    ; clear some state
    lda #0
    sta PPUCTRL
    sta PPUMASK
    bit PPUSTATUS
    ; delay for two frames, to make sure the ppu has started
:   bit PPUSTATUS
    bpl :-
    jsr ClearMemory
:   bit PPUSTATUS
    bpl :-
    ; set some initial ram state
    lda #0
    sta Procedure
    ; enable background layer
    lda #%00001000
    sta PPUMASK
    ; enable NMI interrupt
    lda #%10000000
    sta PPUCTRL
    ; loop until NMI
:   jmp :-

ClearMemory:
    lda #0
    ldy #0
:   sta $000, y
    sta $200, y
    sta $300, y
    sta $400, y
    sta $500, y
    sta $600, y
    sta $700, y
    iny
    bne :-
    rts

; this interrupt executes every frame
NMI:
    ; clear stack
    ldx #$FF
    txs
    ; run a procedure from the nmiprocedures list
    jsr NMIProcedure
    ; loop until next NMI
:   jmp :-

NMIProcedure:
    ; get the next procedure to run, and multiply by 2
    lda Procedure
    asl a
    tax
    ; copy the address to the procedure to run
    lda NMIProcedures, x
    sta ProcedureAddr
    lda NMIProcedures+1, x
    sta ProcedureAddr+1
    ; and execute that function
    jmp (ProcedureAddr)

; nmi procedures has a list of different things that can run at the start of the frame
NMIProcedures:
    ; setup initializes graphics
    .addr Setup
    .addr DoStuff

; this is a macro to write data to the ppu
.macro WriteDataToPPU PPU, Start, Len
    ; update the ppu location
    lda #>PPU
    sta PPUADDR
    lda #<PPU
    sta PPUADDR
    ; and write 'Len' bytes to ppu, starting at the memory location in 'Start'
    ldx #0
:
    lda Start,x
    sta PPUDATA
    inx
    cpx #Len
    bne :-
.endmacro

; setup initializes some ppu data
Setup:
    ; first disable the NMI interrupt so that we can copy data to the ppu without
    ; worrying about getting interrupted
    lda #%00000000
    sta PPUCTRL
    sta PPUMASK
    ; then we set the Procedure to run next frame
    jsr ClearState
    lda #1
    sta Procedure
    ; copy palette data to the PPU
    WriteDataToPPU $3F00, MenuPalette, MenuPaletteEnd - MenuPalette

    lda #$20                  ;and then set it to name table 0
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$04                  ;clear name table with blank tile #24
    ldy #$c0
    lda #$00
:   sta PPUDATA              ;count out exactly 768 tiles
    dey
    bne :-
    dex
    bne :-

    WriteDataToPPU $23C0, Attributes, AttributesEnd - Attributes


    ; and reset the PPU scroll position to the top left corner
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    ; then re-enable NMI so the next frame can run
    lda #%10000000
    sta PPUCTRL
    lda #%00001000
    sta PPUMASK
    rts


IsResetting   = $F2
CurrentInputs = $F1
InputCounter  = $F0

ClearState:
    lda #0
    sta CurrentInputs
    sta InputCounter
    sta $30
    sta $31
    sta $32
    sta $33
    sta $34
    sta $35
    sta $36
    sta $37
    sta $38
    lda #$20
    sta $C0
    lda #$21
    sta $C1
    rts

CheckForReset:
    ldy IsResetting          ; are we currently resetting?
    bne @CheckForClear       ; yes - skip ahead
    cmp #%00110000           ; no - check for start + select
    bne @Done                ; not pressed, return
    inc IsResetting          ; start+select pressed, prepare exit
    bne @Done                ; return
 @CheckForClear:
    cmp #%00000000           ; are all buttons released?
    bne @Done                ; nope - wait until all buttons released
    jmp BOOT                 ; ok - reboot!
@Done:
    lda HeldButtons          ; reload buttons
    rts                      ; and exit

DoStuff:
    ldy #$00
    jsr PlaceArrow
    jsr ReadJoypadsCurrent
    jsr CheckForReset
    cmp CurrentInputs
    beq @finish
    jsr IncrementLine
    lda HeldButtons
    sta CurrentInputs
    jsr PrepareInputText
    jsr ShowSequenceValue
@finish:
    jsr ShowSequenceCounter
    inc InputCounter
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    rts

IncrementLine:
    lda #1
    sta InputCounter
    clc
    lda $C1
    adc #$20
    sta $C1
    lda $C0
    adc #0
    sta $C0
    cmp #$23
    bne @done
    lda $C1
    cmp #$A1
    bne @done
    lda #$20
    sta $C0
    lda #$21
    sta $C1
@done:
    rts



PrepareInputText:
    lda CurrentInputs
    ldx #0
@NextInput:
    pha
    and #%00000001
    beq @store
    lda Inputs,x
@store:
    sta $30,x
    pla
    lsr a
    inx
    cpx #8
    bne @NextInput
    rts


Inputs:
.byte "RLDUTSBA"

ShowSequenceValue:
    jsr ClearNextLine
    lda $C0
    sta PPUADDR
    lda $C1
    sta PPUADDR
    ldy #0
    ldx #9
@NextInput:
    lda $30,y
    beq @Continue
    dex
    sta PPUDATA
@Continue:
    iny
    cpy #9
    bne @NextInput
    lda #0
@Blank:
    sta PPUDATA
    dex
    bne @Blank
    rts

ClearNextLine:
    clc
    lda $C1
    adc #$20
    pha
    lda $C0
    adc #0
    sta PPUADDR
    pla
    sta PPUADDR
    lda #0
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    rts
    

ShowSequenceCounter:
    lda $C0
    sta PPUADDR
    lda $C1
    adc #8
    sta PPUADDR
    lda InputCounter
    and #$F0
    lsr a
    lsr a
    lsr a
    lsr a
    adc #'0'
    cmp #$3A
    bcc :+
    adc #6
:   sta PPUDATA
    lda InputCounter
    and #$0F
    adc #'0'
    cmp #$3A
    bcc :+
    adc #6
:   sta PPUDATA
    ldy #$1b
    jsr PlaceArrow
    rts

PlaceArrow:
    lda $C0
    sta PPUADDR
    lda $C1
    adc #$d
    sta PPUADDR
    sty PPUDATA
    rts



BTN_A = %10000000
BTN_B = %01000000
BTN_S = %00100000
BTN_T = %00010000
BTN_U = %00001000
BTN_D = %00000100
BTN_L = %00000010
BTN_R = %00000001

ReadJoypadsCurrent:
    lda #$01
    sta JOYPAD_PORT
    sta HeldButtons
    lsr a
    sta JOYPAD_PORT
@KeepReading:
    lda JOYPAD_PORT
    lsr a
    rol HeldButtons
    bcc @KeepReading
    lda HeldButtons
    rts


; the palette consists of up to 8 groups of 4 colors each
; the first color is the screen background
MenuPalette:
.byte $0F, $3B, $10, $00
.byte $0F, $30, $10, $00
.byte $0F, $27, $10, $00
.byte $0F, $30, $10, $00
MenuPaletteEnd:

Attributes:
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
.byte $FF, $FF, $00, %10001000, $00, $00, $00, $00
AttributesEnd:

; next we want to skip ahead to the very end of the ROM
; and write our interrupts so that the NES knows where in PRG to jump
; on each frame and when the reset button is pressed.
.res $FFFA - *, $00
.word NMI
.word BOOT
.word $fff0