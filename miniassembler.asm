;;;
;; Disassembler / mini assembler
;;;
        .include "include/miniassembler.inc"
disass: .proc
        ldx #20                     ; disassemble 20 lines
        lda pc_low
        sta address_low
        lda pc_high
        sta address_high
        jsr b_hex_address           ; print current address
        lda (pc)
        sta y_register              ; op-code in .Y
        sta temp1
        tay
        and #$f
        bne l1
        jsr handle_bbr_bbs
l1:
        and #7
        bne l2
        jsr handle_rmb_smb
l2:
        and #3
        bne l3
        jsr unknown_op_code
l3:
        ldy y_register          ; Opcode in y
        sty scratch_low         ; Each mnemonic in table is 4 bytes so multiply with 4
        stz scratch_high
        asl scratch_low
        rol scratch_high
        asl scratch_low
        rol scratch_high
        lda #<mnemonics
        clc
        adc scratch_low
        sta scratch_low
        lda #>mnemonics
        adc scratch_high
        sta scratch_high        ; scratch points to mnemonic

        jmp print_mnemonic      ; print machine code and mnemonic

; op code is in y_register (should change name of label)
; current address is in scratch.
; copy scratch to address and increase it depending on addressing mode.
;

handle_bbr_bbs:
handle_rmb_smb:
unknown_op_code:

        rts
        .pend
error: .null "error"

;;;
;; print mnemonics
;;;
print_mnemonic .proc
        jsr print_machine_code_store_address_mode_as_text
        jsr inc_scratch
        ldy #0
again:
        lda (scratch),y
        sta input_buffer,y
        iny
        cpy #3
        bne again
        lda #0                          ; terminate string with 0
        sta input_buffer,y
        jsr b_space
        lda #<input_buffer
        sta index_low
        lda #>input_buffer
        sta index_high
        jsr b_prout                     ; print mnemonic
        jsr b_space
        jsr print_address_mode
next:
        rts
        .pend

;; '*', Absolute a,                                     3 bytes
;; '@', Implied i, Stack s, Accumulator A               1 byte
;; '~', Absolute Indexed Indirect (a,x)                 3 bytes
;; ':', Absolute Indexed with X a,x                     3 bytes
;; '!', Absolute Indexed with Y a,y                     3 bytes
;; '/', Absolute Indirect (a)                           3 bytes
;; '#', Immediate #                                     2 bytes
;; '$', Program Counter Relative r                      2 bytes
;; '%', Zero Page zp                                    2 bytes
;; '^', Zero Page Indexed Indirect (zp,x)               2 bytes
;; '&', Zero Page Indexed with X zp,x                   2 bytes
;; '(', Zero Page Indexed with Y zp,y                   2 bytes
;; ')', Zero Page Indirect (zp)                         2 bytes
;; '=', Zero Page Indirect Indexed with Y (zp),y        2 bytes
;; '|', not implemented                                 1 byte

print_machine_code_store_address_mode_as_text: .proc
        phx
        lda (scratch)         ; load address mode
        sta address_mode
        ldx #<three_bytes_tokens_end-three_bytes_tokens-1
next_three_bytes_token:
        dex
        bmi two_bytes
        cmp three_bytes_tokens,x
        bne next_three_bytes_token
        jmp print_three_bytes

two_bytes:
        ldx #<two_byte_token_end-two_byte_token-1
next_two_bytes_token:
        dex
        bmi one_byte
        cmp two_byte_token,x
        bne next_two_bytes_token
        jmp print_two_bytes

one_byte:
        jmp print_one_byte
        .pend

; WIP
print_three_bytes: .proc
        jsr b_space
        lda (pc)
        sta temp1
        jsr b_hex_byte
        jsr b_space
        jsr inc_pc
        lda (pc)
        sta addressing_mode_low
        sta temp1
        jsr b_hex_byte
        jsr b_space
        jsr inc_pc
        lda (pc)
        sta addressing_mode_high
        sta temp1
        jsr b_hex_byte
        jsr inc_pc
        jsr b_space
        plx
        rts
        .pend

print_two_bytes: .proc
        jsr b_space
        lda (pc)
        sta temp1
        jsr b_hex_byte
        jsr b_space
        jsr inc_pc
        lda (pc)
        sta addressing_mode_low
        sta temp1
        jsr b_hex_byte
        jsr inc_pc
        jsr b_space4
        plx
        rts
        .pend

debug_me_true: .text "should happen"
debug_me_false: .text "should not happen"

print_one_byte: .proc
        jsr b_space
        lda (pc)
        sta temp1
        jsr b_hex_byte
        jsr inc_pc
        jsr b_space4
        jsr b_space2
        jsr b_space
        plx
        rts
        .pend

print_address_mode: .proc
        lda address_mode
        cmp #'@'                ; Implied i, Stack s, Accumulator A
        bne check_immediate
        rts
check_immediate:
        cmp #'#'                ; Immediate #
        bne check_absolute
        lda #'#'
        jsr b_chout
        jsr b_dollar
        lda addressing_mode_low
        sta temp1
        jmp b_hex_byte
check_absolute:
        cmp #'*'
        bne check_aii             ; absolute indexed indirect
;;;
;; handle absolute a
;;;
        jsr b_dollar
        lda addressing_mode_low
        sta address_low
        lda addressing_mode_high
        sta address_high
        jmp b_hex_address

check_aii:
        cmp #'~'
        bne check_aix               ; absolute indexed with x a,x
;;;
;; handle absolute indexed indirect
;;;
        rts
check_aix:
        cmp #':'
        bne check_aiy             ; absolute indexed with y a,y

;;;
;; handle absolute indexed with x a,x
;;;
        rts
check_aiy:
        cmp #'!'
        bne check_ai              ; absolute indirect (a)

;;;
;; handle absolute indexed with y a,y
;;;
        rts
check_ai:
        cmp #'/'
        bne check_pc_relative     ; all branch op codes

;;;
;; handle absolute indirect (a)
;;;
        rts
check_pc_relative:
        cmp #'$'
        bne check_zero_page         ; zero page

;;;
;; handle all branch op codes
;;;
        jsr b_dollar
        lda addressing_mode_low
        bmi negative_address
        clc
        adc pc_low
        sta address_low
        lda pc_high
        adc #0                      ; add possible carry
        sta address_high
        bra address_out             ; print the address
negative_address:
        eor #$ff                    ; find two-compliment
        ina
        sta temp1
        sec
        lda pc_low
        sbc temp1
        sta address_low
        lda pc_high
        sbc #0
        sta address_high
address_out:
        jmp b_hex_address

check_zero_page:
        cmp #'%'
        bne check_zp_ii           ; zero page indexed indirect (zp,x)

;;;
;; handle zero page
;;;
        rts

check_zp_ii:
        cmp #'^'
        bne check_zp_ix           ; zero page indexed with x zp,x
;;;
;; handle zero page indexed indirect (zp,x)
;;;
        rts

check_zp_ix:
        cmp #'&'
        bne check_zp_iy           ; zero page indexed with y zp,y
;;;
;; handle zero page indexed with x zp,x
;;;
        rts

check_zp_iy:
        cmp #'('
        bne check_zp_i            ; zero page indirect (zp)
;;;
;; handle zero page indexed with y zp,y
;;;
        rts

check_zp_i:
        cmp #')'
        bne check_zp_iiy          ; zero page indirect indexced with y (zp),y
;;;
;; handle zero page indirect (zp)
;;;
        rts

check_zp_iiy:
        cmp #'='
        bne check_not_implemented ; unknown op code
;;;
;; handle zero page indirect indexced with y (zp),y
;;;
        rts

check_not_implemented:
        cmp #'|'
        bne exit
exit:
        rts
        .pend

inc_scratch: .proc
        inc scratch_low
        bne return
        inc scratch_high
return:
        rts
        .pend

inc_pc: .proc
        inc pc_low
        bne done
        inc pc_high
done:
        rts
        .pend
