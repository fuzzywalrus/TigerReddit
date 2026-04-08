# Building Tiger/Leopard-Compatible .icns Icons

## The Problem

Modern macOS tools (`iconutil`, `sips`) create .icns files with PNG-compressed
entries (`ic04`, `ic05`, `ic07`, `ic08`, `ic09`, etc.) that Mac OS X 10.4 Tiger
and 10.5 Leopard cannot display. The app icon shows as a generic "?" or is
completely invisible.

## The Solution

Tiger and Leopard require the classic .icns format with raw/RLE-compressed
icon entries using the old OSType codes.

## Required Icon Entries

| Type   | Size    | Description              | Data Format                    |
|--------|---------|--------------------------|--------------------------------|
| `ics#` | 16x16   | 1-bit icon + mask        | Raw bits: 32B icon + 32B mask  |
| `is32` | 16x16   | 24-bit RGB icon          | Apple icns RLE, channel-planar |
| `s8mk` | 16x16   | 8-bit alpha mask         | Raw bytes, uncompressed        |
| `ICN#` | 32x32   | 1-bit icon + mask        | Raw bits: 128B icon + 128B mask|
| `il32` | 32x32   | 24-bit RGB icon          | Apple icns RLE, channel-planar |
| `l8mk` | 32x32   | 8-bit alpha mask         | Raw bytes, uncompressed        |
| `it32` | 128x128 | 24-bit RGB icon          | 4-byte zero header + Apple RLE |
| `t8mk` | 128x128 | 8-bit alpha mask         | Raw bytes, uncompressed        |

## CRITICAL: Apple icns RLE is NOT Standard PackBits

This is the key finding. Many references incorrectly call the compression
"PackBits," but Apple's icns format uses a **different RLE scheme** with
different control byte encoding. Using standard PackBits produces icons
with correct shapes but completely garbled colors (horizontal stripes).

### Apple icns RLE Encoding Rules

**Decoding:**
- Byte `n` where `0 <= n <= 127`: literal run — copy next `(n + 1)` bytes
- Byte `n` where `128 <= n <= 255`: repeat run — repeat next byte `(n - 125)` times

**Encoding:**
- Literal sequence of L bytes (1-128): write `(L - 1)`, then the L bytes
- Run of R identical bytes (3-130): write `(R + 125)`, then the byte value

### Comparison with Standard PackBits

| Operation              | Standard PackBits    | Apple icns RLE      |
|------------------------|---------------------|---------------------|
| Run of 5 identical     | Control = `0xFC`    | Control = `0x82`    |
| Run of 3 identical     | Control = `0xFE`    | Control = `0x80`    |
| Literal of 3 bytes     | Control = `0x02`    | Control = `0x02`    |
| Max run length         | 128                 | 130                 |
| Min run length         | 2                   | 3                   |

The difference in control bytes for run-length entries causes the decoder
to read completely wrong amounts of data per channel, making R bleed into
G and G into B — hence the garbled horizontal stripes.

## Channel-Planar RGB Format

The `is32`, `il32`, and `it32` entries store RGB data in **planar** format:
all R values first, then all G values, then all B values. Each channel is
independently RLE-compressed.

```
is32 data = RLE(R[0..255]) + RLE(G[0..255]) + RLE(B[0..255])
il32 data = RLE(R[0..1023]) + RLE(G[0..1023]) + RLE(B[0..1023])
it32 data = 0x00000000 + RLE(R[0..16383]) + RLE(G[0..16383]) + RLE(B[0..16383])
```

Note: `it32` has a 4-byte zero header before the RLE data. `is32` and `il32` do not.

## 1-Bit Masks (ics# and ICN#)

These contain TWO bitmaps concatenated: the icon image followed by the mask.
Both are 1-bit-per-pixel, packed 8 pixels per byte, MSB = leftmost pixel,
row by row from top to bottom.

- `ics#`: 16x16 = 32 bytes icon + 32 bytes mask = 64 bytes total
- `ICN#`: 32x32 = 128 bytes icon + 128 bytes mask = 256 bytes total

For simplicity, both the icon and mask portions can be identical (derived
from the alpha channel thresholded at 128).

## 8-Bit Alpha Masks (s8mk, l8mk, t8mk)

Raw uncompressed bytes, one per pixel, 0 = fully transparent, 255 = fully
opaque. Row-major order, top to bottom, left to right.

## .icns File Structure

```
Offset  Content
0       "icns" (magic bytes)
4       Total file size (big-endian uint32)
8+      Chunks: [4-byte type][4-byte chunk size][payload]
        Chunk size includes the 8-byte header.
```

## Python Encoder

```python
def encode_icns_rle(channel_data):
    """Apple icns RLE encoder — NOT standard PackBits!"""
    result = bytearray()
    i = 0
    length = len(channel_data)
    while i < length:
        # Check for run of 3+ identical bytes
        if (i + 2 < length and
            channel_data[i] == channel_data[i+1] == channel_data[i+2]):
            val = channel_data[i]
            run_len = 3
            while (i + run_len < length and
                   channel_data[i + run_len] == val and run_len < 130):
                run_len += 1
            result.append(run_len + 125)  # 128 for 3 copies
            result.append(val)
            i += run_len
        else:
            # Literal run
            lit_start = i
            while i < length and (i - lit_start) < 128:
                if (i + 2 < length and
                    channel_data[i] == channel_data[i+1] == channel_data[i+2]):
                    break
                i += 1
            lit_len = i - lit_start
            result.append(lit_len - 1)  # 0 for 1 byte
            result.extend(channel_data[lit_start:lit_start + lit_len])
    return bytes(result)
```

## Tools That Do NOT Work for Tiger/Leopard Icons

- `iconutil` on modern macOS — creates PNG entries only (ic04, ic05, etc.)
- `sips -s format icns` on modern macOS — creates ic09 (512x512 PNG) only
- `sips -s format icns` on Leopard — not supported
- Standard PackBits compression — wrong control byte encoding

## Tools That Work

- Custom Python script with Apple icns RLE (this document)
- Icon Composer (Xcode 2.x/3.x Developer Tools on Tiger/Leopard)
- Any tool that generates the classic `is32`/`il32`/`it32` format

## Reference

The Lemoniscate project (lemoniscate-ppc) has a working .icns at:
`resources/lemoniscate.icns` — 53,958 bytes with exactly the 8 entries
described above. It was used as the reference implementation for
verifying the format.
