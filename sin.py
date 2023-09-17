#!/usr/bin/env python3

import argparse
import itertools
import math
import serial
import serial.tools.list_ports
import sys
from typing import Iterable, List

def parse_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        'port',
        help='The port on which to connect. Pass ? to list ports.'
    )

    parser.add_argument(
        '-n',
        type=int,
        default=160,
        help='The number of samples in the generated waveform.'
    )

    parser.add_argument(
        '--fcpu',
        type=int,
        default=16000000,
        help='The frequency of the CPU clock.'
    )

    parser.add_argument(
        '--dslope',
        type=float,
        default=0.05,
        help='The delta slope used when modulating the waveform.'
    )

    parser.add_argument(
        '-vmod',
        action='store_true',
        default=False,
        help='Show verbose output from modulation.'
    )

    parser.add_argument(
        '-vpack',
        action='store_true',
        default=False,
        help='Show verbose output from packing.'
    )

    return parser.parse_args()


def quantize(cmd: float, fbk: float) -> int:
    err = cmd - fbk
    return 1 if 0 <= err else -1


def modulate(f, slope: float, interval: float) -> Iterable[int]:
    i = 0
    fbk = 0.0
    while True:
        cmd = f(interval * i)
        q = quantize(cmd, fbk)
        yield (cmd, fbk, q)
        i += 1
        fbk += slope * q


def make_sinf(fsin: float):
    return lambda t: math.sin(2*math.pi*t*fsin)


def rotate_and_drop(bits: List[int]) -> List[int]:
    """
    Rotate the bits so that the first and last bit repeat.
    Drop the last bit; it will be repeated in playback.
    """
    if bits[0] == bits[-1]:
        return bits[:-1]

    for i in range(1, len(bits)):
        if bits[i-1] == bits[i]:
            return bits[i:] + bits[:i-1]

    raise Exception("No rotation index found!")


def pack(bits: List[int]) -> bytearray:
    packed = bytearray(30)
    packed[0] = len(bits)

    i = 1
    b = 0
    for bit in reversed(bits):
        if 7 < b:
            b = 0
            i += 1
        packed[i] = packed[i] | (bit << b)
        b += 1

    # Always duplicate the last byte in the last index.
    # Playout relies on this in its loop logic.
    packed[29] = packed[i]
    return packed


def main():
    args = parse_arguments()

    tsample = 2.0 / args.fcpu
    print(f"tsample={tsample:6g}")

    fsin = 1 / (args.n * tsample)
    print(f"fsin={fsin:6g}")
    
    sinf = make_sinf(fsin)
    samples = list(itertools.islice(modulate(sinf, args.dslope, tsample), args.n))

    if args.vmod:
        for x in samples:
            print(f"{x[2]:+d} {x[0]:10.6f} {x[1]:10.6f}")

    bits = [1 if 0 < x[2] else 0 for x in samples]
    rotated = rotate_and_drop(bits)
    packed = pack(rotated)

    if args.vpack:
        packed_hex = (f"{x:02x}" for x in packed)
        print(f"packed={''.join(packed_hex)}")

    with serial.Serial(args.port, 9600) as s:
        print(f"{args.port} open, expecting ready signal...", end='')
        sys.stdout.flush()
        ready = s.read(1)
        if ready[0] != ord('?'):
            print()
            print(f"expected '?' got {chr(ready[0])}")
            return 1

        print('ok')
        print('writing packed data...', end='')
        sys.stdout.flush()

        s.write(packed)
        s.flush()

        done = s.read(1)
        if done[0] != ord('.'):
            print()
            print(f"expected '.' got {chr(ready[0])}")
            return 1

        print('done')

    return 0


if '__main__' == __name__:
    sys.exit(main())
