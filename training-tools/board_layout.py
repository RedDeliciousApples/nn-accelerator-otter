"""Memory map shared by Python, firmware and RTL. See BOARD_FORMAT.md.

All values are little-endian and every region is 4-byte aligned.
"""

MEM_SIZE = 0x10000  # OTTER memory, bytes (MMIO starts here)

IN_SIZE = 784
HIDDEN_SIZE = 32
OUT_SIZE = 10

# name: (address, size in bytes, element width in bytes)
REGIONS = {
    "HIDDEN_W":     (0x4000, HIDDEN_SIZE * IN_SIZE, 1),   # int8 [32][784]
    "HIDDEN_B":     (0xA200, HIDDEN_SIZE * 4, 4),         # int32 [32]
    "OUTPUT_W":     (0xA280, OUT_SIZE * HIDDEN_SIZE, 1),  # int8 [10][32]
    "OUTPUT_B":     (0xA3C0, OUT_SIZE * 4, 4),            # int32 [10]
    "HIDDEN_SHIFT": (0xA3E8, 4, 4),                       # int32
    "IMAGE":        (0xA400, IN_SIZE, 1),                 # int8 [784]
    "SCORES":       (0xA800, OUT_SIZE * 4, 4),            # int32 [10], written by accelerator
}

CODE_LIMIT = 0x4000  # code must fit below HIDDEN_W


def addr(name):
    return REGIONS[name][0]


def size(name):
    return REGIONS[name][1]


def check_layout():
    previous_end = CODE_LIMIT
    for name, (address, length, width) in sorted(REGIONS.items(), key=lambda r: r[1][0]):
        assert address % 4 == 0, f"{name} not word aligned"
        assert length % width == 0, f"{name} size not a multiple of its element width"
        assert address >= previous_end, f"{name} overlaps the previous region"
        previous_end = address + length
    assert previous_end <= MEM_SIZE


check_layout()
