;
; avr-delta-mod-periodic.asm
;
; Created: 9/15/2023 6:49:42 PM
; Author : comra
;

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
	jmp unhandled_loop


irq_reset:
	; Set stack pointer in case I want to use interrupts or calls.
	ldi r20, high(RAMEND)
	out SPH, r16
	ldi r20, low(RAMEND)
	out SPL, r16

	; Disable pull-ups so that clocking out the waveform doesn't keep
	; toggling active pull-ups on PC1-PC6.
	ldi r16, (1<<PUD)
	out MCUCR, r16

	; Set PC0 as output, PC1-PC6 as inputs.
	ldi r16, (1<<DDC0)
	out DDRC, r16

	; TODO(comradex): get data from serial port.
	ldi XH, high(8)
	ldi XL, low(8)

	; loop address is clkout_end + -2*N + 1
	ldi r16, -2
	ldi r17, 8 ; N
	mulsu r16, r17
	
	ldi r16, 1
	ldi r17, 0
	add r0, r16
	adc r1, r17

	ldi ZH, high(clkout_end)
	ldi ZL, low(clkout_end)
	add ZL, r0
	adc ZH, r1

	ldi r28, 0x55
	ijmp

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
