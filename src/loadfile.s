;----------------------------------------------
; Copy data from SD card to memory location
;----------------------------------------------

	.importzp zp_sd_address, fat32_address, fat32_bytesremaining, fat32_errorstage
	.import fat32_init, fat32_openroot, fat32_opendirent, fat32_finddirent
	.import fat32_readdirent, fat32_file_read

	.import sd_init

	.import via_init, newline, print_char, print_hex, get_input, exit


	.segment "ZEROPAGE"

file_size:		.res 2
copy_destination:	.res 2
file_name:		.res 11
input_buffer:   .res 16
print_pointer:		.res 2
bcd:			.res 3
tmp1:			.res 1
tmp2:			.res 1

	.segment "CODE"

reset:
  cld
  ldx #$ff
  txs
;----------------------------------------------
; SD card and FAT32 initilization
;----------------------------------------------
  jsr via_init
  jsr sd_init
  jsr fat32_init
  bcc initsuccess
  ; Error during FAT32 initialization
  lda #'Z'
  jsr print_char
  lda fat32_errorstage
  jsr print_hex
  jmp exit
initsuccess:
;----------------------------------------------
; Input prompt
;----------------------------------------------
print_help:
  jsr newline
  ldx #<help_menu
  ldy #>help_menu
  stx print_pointer
  sty print_pointer+1
  jsr print_string
print_prompt:
  jsr newline
  lda #'>'
  jsr print_char
  lda #' '
  jsr print_char
read_prompt_input:
  jsr get_input
  cmp #'H'
  beq print_help
  cmp #'D'
  beq print_dir
  cmp #'L'
  beq load_file
  cmp #'X'
  bne print_prompt
  jmp exit
;----------------------------------------------
; Print Directory
;----------------------------------------------
print_dir:
  jsr fat32_openroot
next_entry:
  jsr fat32_readdirent
  bcs print_prompt	; carry set when done
  cmp #$20		; is it a 'normal' file?
  bne next_entry		; no, try next
  ldy #30
  lda (zp_sd_address),y		; is filesize > 64kb
  bne next_entry		; yes, skip
  iny
  lda (zp_sd_address),y
  bne next_entry
  jsr newline
  ldy #0
  sty tmp1
prt_dirent:
  ldy tmp1
  lda (zp_sd_address),y
  jsr print_char
  inc tmp1
  lda tmp1
  cmp #11
  beq prt_size
  cmp #8
  bne prt_dirent
  lda #' '
  jsr print_char
  bne prt_dirent
prt_size:
  lda #' '
  jsr print_char
  lda #' '
  jsr print_char
  ldy #28
  lda (zp_sd_address),y
  sta tmp1
  iny
  lda (zp_sd_address),y
  sta tmp2
  jsr print_size
  jmp next_entry
;----------------------------------------------
; File reading
;----------------------------------------------
load_file:
  jsr newline
  ldx #<input_filename
  ldy #>input_filename
  stx print_pointer
  sty print_pointer+1
  jsr print_string
  jsr read_input
  ; ----
.ifdef DEBUG
  jsr newline
  lda #'>'
  jsr print_char
  ldx #0
fname:
  lda file_name,x
  jsr print_char
  inx
  cpx #11
  bne fname
  lda #'<'
  jsr print_char
.endif
  ; ----
  ; Find file by name
  jsr fat32_openroot
  ldx #<file_name
  ldy #>file_name
  jsr fat32_finddirent
  bcc foundfile
  ; File not found
  jsr newline
  ldx #<file_not_found
  ldy #>file_not_found
  stx print_pointer
  sty print_pointer+1
  jsr print_string
  ; Open root directory
  jsr fat32_openroot
  jmp print_prompt
foundfile:
  jsr newline
  ; Get destination address
  ldx #<memory_destination
  ldy #>memory_destination
  stx print_pointer
  sty print_pointer+1
  jsr print_string
  jsr read_address
  jsr newline
  ; Open file
  jsr fat32_opendirent
  ; Store file size
  lda fat32_bytesremaining+1
  sta tmp2
  lda fat32_bytesremaining
  sta tmp1
  ; Read file contents into memory
  lda copy_destination+1
  sta fat32_address
  lda copy_destination
  sta fat32_address+1
  ldx #<reading
  ldy #>reading
  stx print_pointer
  sty print_pointer+1
  jsr print_string
  jsr print_size
  ldx #<bytes
  ldy #>bytes
  stx print_pointer
  sty print_pointer+1
  jsr print_string
  ; Can hang on the file read sometimes
  jsr fat32_file_read
  ; Return to prompt
  jsr print_prompt
  jsr newline
;----------------------------------------------
; Read in filename
;----------------------------------------------
read_input:
  ldx #0
read_next:
  jsr get_input
  cmp #$0a
  beq input_done
  cmp #$0d
  beq input_done
  cmp #8
  bne store_char
  cpx #0
  bcc read_next
  dex
  bpl read_next
store_char:
  sta input_buffer, x
  cpx #$0f
  bcs read_next
  inx
  bne read_next
input_done:
  stx tmp1
  cpx #0
  bne copy_fname
  jmp print_prompt
copy_fname:
  ldy #0
  ldx #10
  lda #' '
clear_fname:
  sta file_name,x
  dex
  bpl clear_fname
  inx
copy_char:
  lda input_buffer,x
  cmp #'.'
  beq is_dot
  sta file_name,y
  iny
  inx
  cpx tmp1
  bne copy_char
  rts
is_dot:
  ldy #8
  inx
  bne copy_char
;----------------------------------------------
; Read in address to copy data to
;----------------------------------------------
read_address:
  ldx #0
read_address_next:
  jsr get_input              ; read first digit of hex address,
  cpx #2
  beq read_address_done
  and #$0F                   ; '0'-'9' -> 0-9
  asl                        ; multiply by 2
  sta copy_destination, x    ; temp store in temp
  asl                        ; again multiply by 2 (*4)
  asl                        ; again multiply by 2 (*8)
  clc
  adc copy_destination, x    ; as result, a = x*8 + x*2
  sta copy_destination, x
  jsr get_input              ; read second digit of hex address
  and #$0f                   ; '0'-'9' -> 0-9
  adc copy_destination, x
  jsr hex_to_dec
  sta copy_destination, x
  inx
  jmp read_address_next
read_address_done:
  rts
;----------------------------------------------
; Print file size
;----------------------------------------------
print_size:
  lda #0
  sta file_name+1
  jsr binbcd16
  ldx #2
num_bytes:
  lda bcd,x
  lsr a
  lsr a
  lsr a
  lsr a
  jsr check_skip0
  jsr print_hex
;  bcc prt_dig
  lda #0
  rol		; save carry
  sta file_name+1
prt_dig:
  lda bcd,x
  jsr check_skip0
  jsr print_hex
  bcc next_dig
  lda #1
  sta file_name+1
next_dig:
  dex
  bpl num_bytes
  rts
check_skip0:
  tay
  clc
  lda file_name+1
; beq check_done
;  sec
;check_done:
  ror
  tya
  rts
;----------------------------------------------
; Print string whos address is in print_pointer
;----------------------------------------------
print_string:
  ldx #0
print_string_loop:
  txa
  tay
  lda (print_pointer), y     ; get from string
  beq print_string_exit      ; end of string
  jsr print_char             ; write to output
  inx
  bne print_string_loop      ; do next char
print_string_exit:
  rts
;----------------------------------------------
; Convert hex string to decimal
;----------------------------------------------
hex_to_dec:
  sed                        ; switch to decimal mode
  tay                        ; transfer accumulator to y register
  lda #00                    ; reset accumulator
hex_loop:
  dey                        ; decrement x by 1
  cpy #00                    ; if y < 0,
  bmi hex_break              ; then break;
  clc                        ; else clear carry
  adc #01                    ; to increment accumulator by 1
  jmp hex_loop               ; branch always
hex_break:
  cld
  rts
;----------------------------------------------
; Convert 16 bit binary value to bcd code
;----------------------------------------------
binbcd16:
  sed                        ; switch to decimal mode
  lda #0                     ; clear the result
  sta bcd+0
  sta bcd+1
  sta bcd+2
  ldx #16		     ; the number of source bits

cnvbit:
  asl tmp1             	     ; shift out one bit
  rol tmp2
  lda bcd+0                  ; and add into result
  adc bcd+0
  sta bcd+0
  lda bcd+1                  ; propagating any carry
  adc bcd+1
  sta bcd+1
  lda bcd+2	             ; ... thru whole result
  adc bcd+2
  sta bcd+2
  dex		             ; and repeat for next bit
  bne cnvbit
  cld		             ; back to binary
  rts		             ; all done

;----------------------------------------------
; Strings
;----------------------------------------------
help_menu:
  .byte "L    Load file"
  .byte $0d, $0a
  .byte "D    list Directory"
  .byte $0d, $0a
  .byte "X    eXit"
  .byte $0d, $0a
  .asciiz "H    Help"
input_filename:
  .asciiz "Input filename > "
file_not_found:
  .asciiz "File not found"
memory_destination:
  .asciiz "Memory destination > "
reading:
  .asciiz "Reading SD card, "
bytes:
  .asciiz " bytes "
