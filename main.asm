;
; avr-delta-mod-periodic.asm
;
; Created: 9/15/2023 6:49:42 PM
;
; Fuses should be set for no bootloader.

.equ f_cpu = 16000000
.equ baud = 9600
.equ uart_ubrr = (f_cpu / (16 * baud)) - 1

.cseg
.org 0x0000
    jmp irq_reset
    jmp irq_int0
    jmp irq_int1
    jmp irq_pcint0
    jmp irq_pcint1
    jmp irq_pcint2
    jmp irq_wdt
    jmp irq_timer2_compa
    jmp irq_timer2_compb
    jmp irq_timer1_capt
    jmp irq_timer1_compa
    jmp irq_timer1_compb
    jmp irq_timer1_ovf
    jmp irq_timer0_compa
    jmp irq_timer0_compb
    jmp irq_timer0_ovf
    jmp irq_spi_stc
    jmp irq_usart_rxc
    jmp irq_usart_udre
    jmp irq_usart_txc
    jmp irq_adc
    jmp irq_ee_ready
    jmp irq_analog_comp
    jmp irq_twi
    jmp irq_spm_ready


irq_int0:
irq_int1:
irq_pcint0:
irq_pcint1:
irq_pcint2:
irq_wdt:
irq_timer2_compa:
irq_timer2_compb:
irq_timer1_capt:
irq_timer1_compa:
irq_timer1_compb:
irq_timer1_ovf:
irq_timer0_compa:
irq_timer0_compb:
irq_timer0_ovf:
irq_spi_stc:
irq_usart_rxc:
irq_usart_udre:
irq_usart_txc:
irq_adc:
irq_ee_ready:
irq_analog_comp:
irq_twi:
irq_spm_ready:
unhandled_loop:
    rjmp unhandled_loop


irq_reset:
    ; Disable pull-ups so that clocking out the waveform doesn't keep
    ; toggling active pull-ups on PC1-PC6.
    ldi r16, (1<<PUD)
    out MCUCR, r16

    ; Set PC0 as output, PC1-PC6 as inputs.
    ldi r16, (1<<DDC0)
    out DDRC, r16

    ; Set baud rate.
    ldi r17, high(uart_ubrr)
    ldi r16, low(uart_ubrr)
    sts UBRR0H, r17
    sts UBRR0L, r16

    ; Set: Ansynchronous, N parity, 1 stop bit.
    ldi r16, (1<<UCSZ00) | (1 <<UCSZ01)
    sts UCSR0C, r16

    ; Enable RX, TX, no interrupts.
    ldi r16, (1<<RXEN0) | (1<<TXEN0)
    sts UCSR0B, r16

    call uart_recv_clkout_data

    jmp clkout


; Clock out a delta-modulation-coded cyclic waveform.
;
; Output is to PC0. Each bit clocked out writes to the whole PORTC byte, so
; the other PORTC pins will either be driven (if configured as outputs) or
; have their pull-ups toggled (if configured as inputs) as the waveform bits
; are shifted past. I set these pins as inputs and set PUD in MCUCR so that
; the pull-ups are disabled. This requires using external pull-up/pull-down
; but avoids side effects on PC1-PC6.
;
; Requires an N+1 bit cyclic waveform. N bits are stored. The last bit is
; repeated for two periods. Therefore the desired waveform must contain at
; least one ...00... or ...11... for the "seam".
;
; N-1 waveform bits are packed into M waveform bytes, starting from the last
; bit. A 17-bit waveform would fully occupy two bytes:
;
; bit N   15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
; byte M  -- M1 ----------------- -- M0 -----------------
;
; This packing puts the variable-length byte first in each iteration.
;
; Loading consecutive bytes from memory is too slow. It requires two cycles
; per byte. To generate the waveform at CLK/2, I only have one cycle to load
; each byte. Therefore I preload the whole waveform into registers. 
;
; AVR has 32 registers r0...r31. I use these as follows:
;
;  r0...r27         byte 0...M-1
;  r28              byte M
;  r29				active data byte
;  r30, r31 (Z)		loop address
;
; Therefore the maximum length of the waveform is (29*8)+1 => 233 bits.
;
; Byte M (the first in the waveform) is always stored in r28, regardless of
; how many bytes are actually used. It must be in a fixed register so that
; it can be loaded before the jump.
;
; At entry,
;	clkout_bit_count	number of bits in the data
;	clkout_bytes		data bytes that will be copied to r0...r28
;                       (remember that byte M always goes in r28)
;
; This subroutine never returns.

.dseg
clkout_bit_count: .byte 1
clkout_bytes: .byte 29

.cseg
clkout:
    ; loop address is clkout_end + -2*N + 1
    ldi r16, -2
    lds r17, clkout_bit_count ; N
    mulsu r16, r17
    
    ldi r16, 1
    ldi r17, 0
    add r0, r16
    adc r1, r17

    ldi ZH, high(clkout_end)
    ldi ZL, low(clkout_end)
    add ZL, r0
    adc ZH, r1
    push ZH
    push ZL

    ; Using Z register uses half as many program bytes as loading
    ; from immediate addresses.
    ldi ZH, high(clkout_bytes)
    ldi ZL, low(clkout_bytes)
    ld r0, Z+
    ld r1, Z+
    ld r2, Z+
    ld r3, Z+
    ld r4, Z+
    ld r5, Z+
    ld r6, Z+
    ld r7, Z+
    ld r8, Z+
    ld r9, Z+
    ld r10, Z+
    ld r11, Z+
    ld r12, Z+
    ld r13, Z+
    ld r14, Z+
    ld r15, Z+
    ld r16, Z+
    ld r17, Z+
    ld r18, Z+
    ld r19, Z+
    ld r20, Z+
    ld r21, Z+
    ld r22, Z+
    ld r23, Z+
    ld r24, Z+
    ld r25, Z+
    ld r26, Z+
    ld r27, Z+
    ld r28, Z+

    ; Preload r29 because the loop address never goes to a load
    ; instruction.
    mov r29, r28

    pop ZL
    pop ZH
    ijmp

.macro clkout_byte
    mov r29, @0
    out PORTC, r29
    lsr r29
    out PORTC, r29
    lsr r29
    out PORTC, r29
    lsr r29
    out PORTC, r29
    lsr r29
    out PORTC, r29
    lsr r29
    out PORTC, r29
    lsr r29
    out PORTC, r29
    lsr r29
    out PORTC, r29
.endmacro

    clkout_byte r28
    clkout_byte r27
    clkout_byte r26
    clkout_byte r25
    clkout_byte r24
    clkout_byte r23
    clkout_byte r22
    clkout_byte r21
    clkout_byte r20
    clkout_byte r19
    clkout_byte r18
    clkout_byte r17
    clkout_byte r16
    clkout_byte r15
    clkout_byte r14
    clkout_byte r13
    clkout_byte r12
    clkout_byte r11
    clkout_byte r10
    clkout_byte r9
    clkout_byte r8
    clkout_byte r7
    clkout_byte r6
    clkout_byte r5
    clkout_byte r4
    clkout_byte r3
    clkout_byte r2
    clkout_byte r1
    clkout_byte r0
clkout_end:
    mov r29, r28
    ijmp


; Receives 30 bytes defining the clkout waveform.
;
; Sends '?' when it is ready to receive bytes.
; Sends '.' when it has received all the bytes.

uart_recv_clkout_data:
    ; Send ready.
    rcall uart_await_xmit_ready
    ldi r16, '?'
    sts UDR0, r16

    ; Receive 30 bytes starting at clkout_bit_count.
    ldi r17, 30
    ldi XH, high(clkout_bit_count)
    ldi XL, low(clkout_bit_count)
uart_recv_clkout_data_next:
    rcall uart_await_recv_ready
    lds r16, UDR0
    st X+, r16
    dec r17
    brne uart_recv_clkout_data_next

    ; Send okay.
    rcall uart_await_xmit_ready
    ldi r16, '.'
    sts UDR0, r16
    
    ret

uart_await_xmit_ready:
    lds r16, UCSR0A
    sbrs r16, UDRE0
    rjmp uart_await_xmit_ready
    ret

uart_await_recv_ready:
    lds r16, UCSR0A
    sbrs r16, RXC0
    rjmp uart_await_recv_ready
    ret
