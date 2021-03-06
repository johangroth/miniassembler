
        .include "include/bios.inc"
        .include "include/zp.inc"
        .include "include/strings.inc"

;;;
;;  INPUT_DEC: Request 1-8 ASCII decimal numbers and convert to binary.
;;
;;       Preparation:
;;                    x: number of decimal characters to read. Max 8.
;;
;;   Returned Values: a: used
;;                    x: number of characters read
;;                    y: used
;;
;;
;;   Examples:
;;             ldx #3         ;read up to three characters, ie one byte
;;             jsr input_dec  ;call subroutine
;;
;;;
input_dec: .proc
        smb 0,control_flags
        rmb 1,control_flags
        jmp input
        .pend

;;;
;;  INPUT_HEX: Request 1-8 ASCII hex numbers and convert to binary.
;;
;;       Preparation:
;;                    x: number of hex characters to get from termnial. Max 8.
;;
;;   Returned Values: a: used
;;                    x: number of characters read
;;                    y: used
;;
;;
;;   Examples:
;;             ldx #2         ;read up to two characters, ie one byte
;;             jsr input_hex  ;call subroutine
;;
;;;
input_hex:  .proc
        rmb 0,control_flags         ;Set flags ...
        rmb 1,control_flags         ;... for hex input
        jmp input
        .pend

;;;
;;  INPUT: Input characters from console, filtered by control_flags.
;;
;;   Preparation:     control_flags set to input mode.
;;
;;   Returned Values: a: Used
;;                    x: Will contain number of characters read
;;                    y: Used
;;        number_buffer: Contains the binary number if x > 0
;;
;;   Examples: rmb 0,control_flags      ;Set flags ...
;;             rmb 1,control_flags      ;... for hex input
;;             jsr input                ;call input
;;
;;;
input:  .proc
        lda #>input_buffer
        ldy #<input_buffer
        jsr read_line               ;x will contain number of characters read
        jmp ascii_to_bin            ;Convert ASCII in input_buffer to binary in number_buffer
        .pend

;;;
;; READ_LINE subroutine: Read characters from terminal until CR is found or maximum characters have been read.
;;                       Derived work from "6502 ASSEMBLY LANGUAGE SUBROUTINES", ISBN: 0-931988-59-4
;;                       Input is filtered so when hex input is set only hex characters will be allowed.
;;                       If a disallowed character is pressed, a bell sound will be sent to console.
;;                       The filter is active for all but 1 input modes which is ASCII text where all characters are allowed.
;;                       READ_LINE recognises BS and CR and CTRL-X.
;;                       BS - deletes the previous character
;;                       CTRL-X - deletes all characters
;;                       CR - subroutine done
;;      Preparation:
;;                           a: high byte of input address
;;                           y: low byte of input address
;;                           x: maximum length of input line
;;               control_flags: 00, hex input
;;                              01, decimal input
;;                              10, binary          TODO
;;                              11, ASCII text
;;      Effect on registers:
;;              a - used
;;              x - will hold number of characters entered at exit
;;              y - used
;;
;;      Example: Read four hex characters from terminal and place them in in_buffer.
;;              rmb 0,control_flags     ; can be replaced with lda #0
;;              rmb 1,control_flags     ; and sta control_flags
;;              lda #>in_buffer
;;              ldy #<in_buffer
;;              ldx #4
;;              jsr read_line
;;
;;      Example: Read four decimal characters from terminal and place them in in_buffer.
;;              smb 0,control_flags     ; can be replaced with lda #1
;;              rmb 1,control_flags     ; and sta control_flags
;;              lda #>in_buffer
;;              ldy #<in_buffer
;;              ldx #4
;;              jsr read_line
;;;
read_line:  .proc
        sta buffer_address_high     ;Save high byte of input buffer address
        sty buffer_address_low      ;Save low byte of input buffer address
        stx buffer_length           ;Save maximum length
init:
        stz buffer_index            ;Initialise buffer index to zero
read_loop:
        jsr read_character          ;Read character from terminal (no echo, converted to uppercase)
        ; sta temp1
        ; jsr hex_byte
        cmp #a_cr                   ;Is character CR
        beq exit_read_line          ;Exit if it is
        cmp #a_bs                   ;Is character BS
        bne l1                      ;No, branch
        jsr backspace               ;Yes remove character from buffer and send destuctive backspace to terminal
        bra read_loop
l1:
        cmp #$5f
        bne iscancel
        jsr backspace
        bra read_loop
iscancel:
        cmp #a_can                  ;Cancel character(s) received (aka CTRL-X)
        bne l2                      ;If not CTRL-X, branch
l3:
        jsr backspace               ;Remove character from buffer and send BS to terminal
        lda buffer_index            ;Is buffer empty
        bne l3                      ;No, continue deleting
        bra read_loop               ;Read next character
        ; Not a special character
        ; Check if buffer full
        ; If not, store character and echo
l2:
.if emulator==true
        tax
        lda control_flags
        bit #1
        bne check_buffer            ;Bit 1 is set which means any character is allowed, so try to store it
        bit #0
        bne decimal_input           ;Bit 0 is set which means decimal input
        txa
.else
        bbs 1,control_flags,check_buffer
        bbs 0,control_flags,decimal_input
.fi
        ; Hexdecimal input
        cmp #'A'                    ;Else hex input
        bcc decimal_input           ;Branch if character is < 'A' (check 0-9)
        cmp #'F'+1
        bcc check_buffer            ;Branch if character is < 'F'+1
decimal_input:
.if emulator==true
        txa
.fi
        cmp #'0'
        bcc ring_bell               ;Branch if character is < '0'
        cmp #'9'+1
        bcs ring_bell               ;Branch if character is >= '9'+1
check_buffer:
.if emulator==true
        txa
.fi
        ldy buffer_index            ;Is buffer
        cpy buffer_length           ;full
        bcc store_character         ;Branch if room in buffer
ring_bell:
        jsr bell                    ;Ring the bell, buffer is full
        bra read_loop               ;Continue
store_character:
        sta (buffer_address_low),y  ;Store the character
        jsr chout                   ;Send character to terminal
        inc buffer_index
        bra read_loop               ;Read next character
exit_read_line:
        ldx buffer_index            ;Exit with X containing amount of characters read
        rts
        .pend

;;;
;; BACKSPACE subroutine: Send BS, SPC, BS to terminal and decrement the readline input buffer index.
;;      NOTE: This subroutine should only be used by read_line as the buffer is private
;;            to read_line.
;;
;;          BS - deletes the previous character
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr backspace
;;;
backspace: .proc
        pha
        lda buffer_index            ;Check for empty buffer
        beq sound_bell              ;If no characters in buffer, branch
        dec buffer_index            ;Decrement the buffer index
        #print_text destructive_backspace
        bra exit
sound_bell:
        jsr bell
exit:
        pla
        rts
        .pend

;;;
;; READ_CHARACTER subroutine: Read a character from terminal and convert it to uppercase.
;;
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - character in uppercase
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr read_character
;;;
read_character: .proc
        jsr chin
        and #extended_ascii_mask        ;Remove all ASCII codes above $7f
        cmp #'a'                        ;Is character less 'a'
        bcc exit                        ;branch if yes, ie number, symbol, uppercase or control character
        sbc #$20                        ;Otherwise substract $20 to convert character to uppercase
exit:
        rts
        .pend


;;;
;; DEC_INDEX subroutine: Decrement 16 bit variable index_low, index_high
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - used
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr dec_index
;;;
dec_index:  .proc
        lda index_low       ;Is index_low being decremented from $00 to $ff?
        bne done            ;No, branch
        dec index_high      ;  Yes, decrement high
done:
        dec index_low       ;Decrement low
        rts
        .pend

;;;
;; INC_INDEX subroutine: Increment 16 bit variable index_low, index_high.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr inc_index
;;;
inc_index:  .proc
        inc index_low       ;Increment low
        bne done            ;if no wrap-around from $ff to $00 take branch
        inc index_high      ;  yes, wrap-around so increment high
done:
        rts
        .pend

;;;
;; SPACEX subroutine: Send X space characters to terminal.
;;;
spacex: .proc
        jsr space
        dex
        bne spacex
        rts
        .pend

;;;
;; SPACE4 subroutine: Send four space characters to terminal.
;;;
space4: .proc
        jsr space2
        .pend

;;;
;; SPACE2 subroutine: Send two space characters to terminal.
;;;
space2: .proc
        jsr space
        .pend

;;;
;; SPACE subroutine: Send a space character to terminal.
;;;
space: .proc
        pha
        lda #' '
        jsr chout
        pla
        rts
        .pend

;;;
;; COLON subroutine: Send colon sign to terminal.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr crout
;;;
colon: .proc
        pha
        lda #':'
        bra crout.sendit
        .pend

;;;
;; DOLLAR subroutine: Send dollar sign to terminal.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr crout
;;;
dollar: .proc
        pha
        lda #'$'
        bra crout.sendit
        .pend

;;;
;; CR2 subroutine: Send CR/LF twice to terminal.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr cr2
;;;
cr2:    .proc
        jsr crout
        .pend

;;;
;; CROUT subroutine: Send CR/LF to terminal.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              jsr crout
;;;
crout:   .proc
        pha
        lda #a_cr
        jsr chout
        lda #a_lf
sendit:
        jsr chout
        pla
        rts
        .pend

;;;
;; PROUT subroutine: Send a zero terminated string to terminal.
;;      Preparation:
;;              index_low  low byte address to string
;;              index_high high byte address to string
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;          text    .null "hello world"
;;                  lda #<text
;;                  sta index_low
;;                  lda #>text
;;                  sta index_high
;;                  jsr prout
;;;
prout:   .proc
        pha                         ;Preserve A
l1:
        lda (index_low)             ;Get character
        beq exit                    ;If eq zero, branch
        jsr chout                   ;Send character to termnial
        jsr inc_index               ;Next character
        bra l1                      ;Loop back
exit:
        pla                         ;Restore A
        rts
        .pend

;;;
;; HEX_ADDRESS subroutine: Send an ASCII hex address to terminal.
;;      Preparation:
;;              address_low:  low byte to send to terminal
;;              address_high: high byte to send to terminal
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;                  lda #$fc
;;                  sta address_low
;;                  lda #$ab
;;                  sta address_high
;;                  jsr hex_address
;;
;;      Terminal will show:
;;                  ABFC
;;;
hex_address: .proc
        pha
        phx
        phy
        jsr hex_mode
        jsr clear_number_buffer
        lda address_low
        sta number_buffer
        lda address_high
        sta number_buffer+1
        jsr binary_to_ascii
        ldx #4
        jsr leading_zeroes
        jsr prout
        ply
        plx
        pla
        rts
        .pend

;;;
;; HEX_BYTE subroutine: Send an ASCII hex byte to terminal.
;;      Preparation:
;;              temp:  byte to send to terminal
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;                  lda #12
;;                  sta temp1
;;                  jsr hex_byte
;;
;;      Terminal will show:
;;                  0C
;;;
hex_byte: .proc
        pha
        phy
        phx
        jsr hex_mode
        jsr clear_number_buffer
        lda temp1
        sta number_buffer
        jsr binary_to_ascii
        jsr prout                   ;send hex character(s) to terminal
        plx
        ply
        pla
        rts
        .pend

;;;
;; HEX_MODE subroutine: Set control_flags to hex conversion.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;                  jsr hex_mode
;;;
hex_mode: .proc
        rmb 0,control_flags
        rmb 1,control_flags
        rts
        .pend

;;;
;; LEADING_ZEROES subroutine: Send ASCII '0' to terminal.
;;      Preparation:
;;              x - maximum number of zeroes to print
;;              a - number of characters to print
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;              ldx #2
;;              jsr leading_zeroes
;;;
leading_zeroes: .proc
        pha
        sta temp2       ;Store number of characters to print
        txa             ;Transfer maximum number of leading zeroes to A
        sec
        sbc temp2       ;Maximum number of zeroes substracted with number of characters to print (ie X - A)
        tax             ;Number of leading zeroes in X
        beq exit        ;No leading zeroes needed
        lda #'0'
l1:
        jsr chout
        dex
        bne l1
exit:
        pla
        rts
        .pend

;;;
;; CLEAR_NUMBER_BUFFER subroutine: Clear the number buffer.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - entry value
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;                  jsr clear_number_buffer
;;;
clear_number_buffer: .proc
        phx
        ldx #3
l1:
        stz number_buffer,x
        dex
        bpl l1
        plx
        rts
        .pend

;;;
;; BELL subroutine: Send a bell sound to terminal.
;;      Preparation:
;;              none
;;
;;      Effect on registers:
;;              a - used
;;              x - entry value
;;              y - entry value
;;
;;      Example:
;;             jsr bell
;;;
bell:   .proc
        lda #a_bel
        bra chout
        .pend


;;;
;; chin_no_wait subroutine: Get character from buffer. If no character is available
;; carry is cleared, otherwise set. Returns character in A register.
chin_no_wait: .proc
        lda $f004
        rts
        .pend

;;; CHIN subroutine: Wait for a character in input buffer, return character in A register.
;;; receive is interrupt driven and buffered with a size of 128 bytes.
chin:    .proc
        lda $f004                   ; py65mon get char
        beq chin                    ; If zero wait for characters
        rts
        .pend

;;; CHOUT subroutine: Place register A in output buffer, register A is preserved.
;;; transmit is interrupt driven and buffered with a size of 128 bytes
chout:   .proc
        sta $f001                   ; py65mon put char
        rts
        .pend
nmi:
        rti

;;;
;; coldstart - initialises all hardware
;; power up and reset procedure.
;;;
coldstart: .block
        sei                     ;Turn off interrupts
        cld                     ;Make sure MPU is in binary mode
        ldx  #0
l1:
        stz  0,x                ;zero ZP
        dex
        bne  l1
        dex                     ;effectively ldx #$ff
        txs                     ;Initialise stack register
        ldx  #n_soft_vectors    ;Initialise IRQ ISR soft vector table
l2:
        lda initial_soft_vectors-1,x
        sta soft_vector_table-1,x
        dex
        bne l2
        ; jsr acia_init         ;Deprecated (ACIA was a CDP/Rockwell 65C51 at 4 MHz)
        ; jsr duart_init          ;Initialise 28L92 (DUART at 4 MHz initially)
        ; jsr rtc_init            ;Initialise real time clock
        ; jsr via_init          ;No VIA on Pluto v2 (well, right now 24/12/2018 one is connected to the expansion bus)
        ; cli

;;;
;; Initialise termnial
;;;
        jsr bell
        lda #<clear_screen
        sta index_low
        lda #>clear_screen
        sta index_high
        jsr prout
        lda #<welcome
        sta index_low
        lda #>welcome
        sta index_high
        jsr prout

;;;
;; Initialise monitor (cold start of monitor).
;;;
        jsr monitor_initialiser
;;;
;; Monitor main loop
;;;
        jmp monitor_main_loop

        .bend

;;;
;; IRQ interrupt service routine
;;;
irq:
        .block
        pha
        phx
        phy
        tsx                     ;Get the stack pointer
        lda stack_page+4,x      ;MPU status register
        and #brk_irq_mask       ;Has brk instruction triggered IRQ
        bne do_break            ;Yes, branch
        jmp (rtc_soft_vector)   ;  no, jump to rtc ISR routine
do_break:
        jmp (brk_soft_vector)   ;Handle brk instruction
        .bend

irq_end: .block
        ply
        plx
        pla
        rti
        .bend

brk_irq: .block
        ply
        plx
        pla
        sta accumulator
        stx x_register
        sty y_register
        pla                     ;Get MPU status register
        sta mpu_status_register
        tsx
        stx stack_pointer
        plx                     ;Pull low byte of return address
        stx pc_low
        stx index_low           ;For disassemble line
        plx
        stx pc_high
        stx index_high          ;For disassemble line
;
; The following 3 subroutines are contained in the base Monitor and S/O/S code
;	- if replaced with new code, either replace or remove these routines
;
		;jsr	decindex      ;decrement index to show brk flag byte in register display
		;jsr	prstat1	      ;display contents of all preset/result memory locations
		;jsr	disline       ;disassemble then display instruction at address pointed to by index

        lda #0      ;clear all processor status flags
        pha
        plp
        stz in_buffer_counter
        stz in_buffer_tail
        stz in_buffer_head
        jmp (monitor_soft_vector)
        .bend

rtc_irq: .block
        ; jmp (acia_soft_vector)          ;Jump to next ISR
        ;; rtc irq doesn't do anything at the moment so
        ;; jump directly to duart ISR.
        jmp (duart_soft_vector)         ;Jump to DUART ISR
        .bend

        * = $ff00
;;;
;; BIOS jump table.
;; This table is the official API of the BIOS. Ideally no other routines should be used.
;;;
b_input_hex:    jmp input_hex           ;Binary number in number_buffer
b_input_dec:    jmp input_dec           ;Binary number in number_buffer
b_read_char:    jmp read_character      ;Read character and convert to uppercase.
b_read_line:    jmp read_line           ;Read .X number of characters
b_chin_no_wait: jmp chin_no_wait        ;Read character but don't wait for input. Used by XMODEM
b_bin_to_asc:   jmp binary_to_ascii     ;Convert a binary to ASCII
b_dollar:       jmp dollar              ;Print '$'.
b_colon:        jmp colon               ;Print ':'
b_chout:        jmp chout               ;Send content .A to console
b_chin:         jmp chin                ;Read datum from console. Value will be in .A.
b_crout:        jmp crout               ;Send CR/LF to console
b_cr2:          jmp cr2                 ;Send two CR/LF to console
b_prout:        jmp prout               ;Send a zero terminated string to console
b_bell:         jmp bell                ;Send BELL to console
b_space:        jmp space               ;Send space character to console
b_space2:       jmp space2              ;Send two space character to console
b_space4:       jmp space4              ;Send four character to console
b_spacex:       jmp spacex              ;Send .X space character to console
b_hex_byte:     jmp hex_byte            ;Print a hex byte with leading zeroes. Byte should be stored in temp1.
b_hex_address:  jmp hex_address         ;Print a hex address with leading zeroes. Address should be stored in address_low and address_high.

        * = $fffa
        .word   nmi         ;NMI
        .word   coldstart   ;RESET
        .word   irq         ;IRQ
