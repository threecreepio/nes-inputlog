; allow line continuation feature
.linecont +

.segment "INES"
.byte $4E,$45,$53,$1A ; ines magic header
.byte 2 ; number of prg sements
.byte 1 ; number of chr segments
.byte %00000001 ; flags 6

.segment "PRG"
.include "prg.asm"

.segment "CHR"
.incbin "charset.chr"
