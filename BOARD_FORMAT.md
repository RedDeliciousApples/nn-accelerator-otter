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

Gaps between regions (e.g. `0xA3EC`-`0xA3FF`) are padding and should be ignored.

Reference implementation: `training-tools/integer_network.py`.

## Generating data

```
python training-tools/export_firmware_data.py [digit 0-9]
```

Writes to `training-tools/artifacts/firmware/`:
- `network_data.s`: `.data` section (link at `0x4000`) with labels
- `otter_data.mem`: full 64 KB image as 16384 32-bit hex words, to merge with the program (since code area is 0).

## Software baseline (RV32I, `firmware/main.c`)

Simulated results (testbench `clk` 50 MHz, so `s_clk` 25 MHz, no hardware multiply):

| Image (`export_firmware_data.py <digit>`) | Predicted | Expected scores (reference) match? | `s_clk` cycles | PC updates | Sim time |
|---|---|---|---|---|---|
| test image 3, label 0 | 0 | yes, all 10 scores identical | 1,276,463 | 612,792 | 51.05852 ms |
| test image 2, label 1 (fastest tested) | 1 | yes, all 10 scores identical | 994,407 | 471,764 | 39.77628 ms |
| test image 1, label 2 | 2 | yes, all 10 scores identical | 1,201,787 | 575,454 | 48.07148 ms |
| test image 18, label 3 (slowest tested) | 3 | yes, all 10 scores identical | 1,287,203 | 618,162 | 51.48812 ms |
| test image 4, label 4 | 4 | yes, all 10 scores identical | 1,104,815 | 526,968 | 44.19260 ms |
| test image 8, label 5 (misclassified) | 6 | yes, all 10 scores identical | 1,221,067 | 585,094 | 48.84268 ms |
| test image 15, label 5 (retry) | 5 | yes, all 10 scores identical | 1,144,171 | 546,646 | 45.76684 ms |
| test image 11, label 6 | 6 | yes, all 10 scores identical | 1,207,359 | 578,240 | 48.29436 ms |
| test image 0, label 7 | 7 | yes, all 10 scores identical | 1,099,631 | 524,376 | 43.98524 ms |
| test image 61, label 8 | 8 | yes, all 10 scores identical | 1,241,747 | 595,434 | 49.66988 ms |
| test image 7, label 9 | 9 | yes, all 10 scores identical | 1,123,051 | 536,086 | 44.92204 ms |


All 11 simulations matched all ten reference scores. The first digit 5 image was also misclassified as 6 by the Python reference; the next digit-5 image passed. Initial accuracy was 9/10 before the retry. Digit 3 took about 29.44% longer than digit 1 among these tested images.

The per-image timing difference comes from the data-dependent length of `__mulsi3`.
Digit 3 scores: `[-4213, -2234, 3548, 6229, -3803, 475, 1528, -3289, 1876, -1850]`.
Digit 7 scores: `[803, -7638, 2991, 6084, -4793, -433, -10638, 13809, 273, 3817]`.
