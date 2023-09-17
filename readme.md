# AVR CPU-Only Delta Modulation Playback

Inspired by an [EEVBlog forum topic](eevblog), this test program clocks out
a cyclic bitstream at 2 cycles per bit, given three caveats:

 1. The desired bitstream is at most 233 bits. This allows preloading
    the whole bitstream into CPU registers, avoiding any memory loads.
    Any memory load requires two cycles, not including a port write.
 2. The bitstream can be arranged so that each cycle starts on a
    repeated symbol. `ijmp` (and every other jump, I think) requires
    two cycles during which the CPU cannot prepare and clock out a bit.
 3. There's no time to mask bits when writing to the port. None of the
    other pins on the output port can be used as outputs, and if used
    as inputs they cannot care about their internal pullup state.

This example was written on an ATMega328p, but the core `clkout` routine
should work on any AVR. I do use `mulsu` for convenience when computing
the loop's `ijmp` target. This could be replaced by a subroutine on an
AVR that does not have a hardware multiply, but I think that's pretty
rare at this point.

Please note that most microcontrollers (even AVRs) will have some kind of
shift register that would alleviate these caveats. See ATTiny85's USI,
USART SPI mode on ATMegas that have it, or even RP2040's PIO peripheral.

Included is a Python script that can modulate and prepack a sine, and
send the bitstream over serial to the microcontroller.

![scope 50khz](scope-50khz.png)

[eevblog]: https://www.eevblog.com/forum/microcontrollers/how-fast-could-serial-bits-read-from-a-table-in-sram-be-outputted/
