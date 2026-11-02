# Board data format

`board_layout.py` is where this is defined.

Network: 784 -> 32 (ReLU) -> 10. All multi-byte values are little-endian, every region is *4-byte aligned, addresses are absolute byte addresses in OTTER memory (64 KB, MMIO starts at `0x10000`).

## Memory map

| Region | Address | Size | Format |
|---|---|---|---|
| Code (`.text`) | `0x0000`-`0x3FFF` | 16 KB | firmware |
| `HIDDEN_W` | `0x4000` | 25,088 B | int8 `[32][784]`, row-major, no row padding. Neuron n, input i at `0x4000 + n*784 + i` |
| `HIDDEN_B` | `0xA200` | 128 B | int32 `[32]` |
| `OUTPUT_W` | `0xA280` | 320 B | int8 `[10][32]`, row-major. Neuron k, input j at `0xA280 + k*32 + j` |
| `OUTPUT_B` | `0xA3C0` | 40 B | int32 `[10]` |
| `HIDDEN_SHIFT` | `0xA3E8` | 4 B | int32 (currently 12) |
| `IMAGE` | `0xA400` | 784 B | int8 `[784]`, 28x28 row-major, `round(pixel * 127)` so 0..127 |
| `SCORES` | `0xA800` | 40 B | int32 `[10]`, written by the accelerator |
| Stack | down from `0xFFFC` | | `0xA900` and up is free |

Gaps between regions (e.g. `0xA3EC`-`0xA3FF`) are padding and must be ignored.

Reference implementation: `training-tools/integer_network.py`.

## Generating data

```
python training-tools/export_firmware_data.py [digit 0-9]
```

Writes to `training-tools/artifacts/firmware/`:
- `network_data.s`: `.data` section (link at `0x4000`) with labels
- `otter_data.mem`: full 64 KB image as 16384 32-bit hex words, to merge with the program (since code area is 0).