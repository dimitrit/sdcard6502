
	.export newline, print_char, print_hex, get_input, exit, via_init

.proc newline
  jmp CRLF
.endproc

.proc print_char
; JSR OUTCH    1EA0     Print ASCII char  A     -       X is preserved
;                       in A on TTY                     Y = FF
;                                                       A = FF
  jmp OUTCH
.endproc

.proc print_hex
; JSR HEXTA    1E4C     Prints A as       A     -       X preserved
;                       Hex Char.                       A = FF
;                                                       Y = FF
  bne prt_hex	; always print digit if not 0
  bcs prt_hex	; if carry clear, replace 0 with space
  lda #' '
  jmp OUTCH
prt_hex:
  jsr HEXTA
  sec
  rts
.endproc

.proc get_input
; JSR GETCH    1E5A     Put character     -     A       X preserved
;                       from TTY in A                   Y = FF
  jsr GETCH
;  cmp #$60
;  bcs done
;  and #$5f	; make uppercase
done:
  rts
.endproc

.proc exit
  jmp EXIT
.endproc

.proc via_init
  lda #%11111111          ; Set all pins on port B to output
  sta DDRB
  lda #PORTA_OUTPUTPINS   ; Set various pins on port A to output
  sta DDRA
  rts
.endproc

  .include "hwconfig.s"
