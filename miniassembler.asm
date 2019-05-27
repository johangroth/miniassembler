;;;
;; Disassembler / mini assembler
;;;
        .include "include/miniassembler.inc"
disass: .proc
        ldx #20                     ; disassemble 20 lines
        jsr b_hex_address           ; print current address
        lda (address)
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
;; returns address mode in .A
;;;
print_mnemonic .proc
        jsr print_machine_code_store_address_mode_as_text
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
        jsr b_prout
        jsr address_mode
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
        ldx #<three_bytes_tokens_end-three_bytes_tokens+1
next_three_bytes_token:
        dex
        cpx #$ff
        beq two_bytes
        cmp three_bytes_tokens,x
        bne next_three_bytes_token
        jmp print_three_bytes

two_bytes:
        ldx #<two_byte_token_end-two_byte_token+1
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
        lda (address)
        sta temp1
        jsr b_hex_byte
        jsr b_space
        jsr inc_address
        lda (address)
        sta temp1
        jsr b_hex_byte
        jsr b_space
        jsr inc_address
        lda (address)
        sta temp1
        jsr b_hex_byte
        jsr inc_scratch
        jsr b_space
        plx
        rts
        .pend

print_two_bytes: .proc
        jsr b_space
        lda (address)
        sta temp1
        jsr b_hex_byte
        jsr b_space
        jsr inc_address
        lda (address)
        sta temp1
        jsr b_hex_byte
        jsr inc_address
        jsr inc_scratch
        jsr b_space4
        plx
        rts
        .pend

debug_me: .text "should happen"

print_one_byte: .proc
        jsr b_space
        lda (address)
        sta temp1
        jsr b_hex_byte
        jsr inc_scratch
        jsr inc_address
        jsr b_space4
        jsr b_space2
        jsr b_space
        plx
        rts
        .pend

inc_scratch: .proc
        inc scratch_low
        bne return
        inc scratch_high
return:
        rts
        .pend


address_mode: .proc

        rts
        .pend
