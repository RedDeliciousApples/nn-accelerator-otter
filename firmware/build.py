"""Build main.c and merge the program into the data image.

usage: python firmware/build.py
Needs riscv64-unknown-elf-gcc with an rv32i/ilp32 multilib on PATH.
Reads training-tools/artifacts/firmware/otter_data.mem (from export_firmware_data.py)
writes firmware/build/program.dis and firmware/build/otter_memory.mem, and copies the
.mem into the Vivado project (2022lab8.srcs/.../otter_memory.mem).
"""
import shutil
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
DATA_MEM = HERE.parent / "training-tools" / "artifacts" / "firmware" / "otter_data.mem"
VIVADO_MEM = HERE.parent / "2022lab8.srcs" / "sources_1" / "imports" / "Downloads" / "otter_memory.mem"
CODE_LIMIT = 0x4000
PREFIX = "riscv64-unknown-elf-"


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


BUILD.mkdir(exist_ok=True)
elf, binary = BUILD / "program.elf", BUILD / "program.bin"
run(PREFIX + "gcc", "-march=rv32i", "-mabi=ilp32", "-O2", "-nostdlib", "-ffreestanding",
    "-T", HERE / "link.ld", HERE / "start.S", HERE / "main.c", "-lgcc", "-o", elf)
run(PREFIX + "objcopy", "-O", "binary", elf, binary)
with open(BUILD / "program.dis", "w") as f:
    subprocess.run([PREFIX + "objdump", "-d", elf], check=True, stdout=f)

program = binary.read_bytes()
assert len(program) <= CODE_LIMIT, f"program is {len(program)} bytes, limit {CODE_LIMIT}"
program += bytes(-len(program) % 4)

words = DATA_MEM.read_text().split()
program_words = [int.from_bytes(program[i:i + 4], "little") for i in range(0, len(program), 4)]
assert all(int(w, 16) == 0 for w in words[:CODE_LIMIT // 4]), "code area of the data image is not empty"
words[:len(program_words)] = [f"{w:08x}" for w in program_words]
(BUILD / "otter_memory.mem").write_text("\n".join(words) + "\n")
print(f"program: {len(program)} bytes -> {BUILD / 'otter_memory.mem'}")
shutil.copyfile(BUILD / "otter_memory.mem", VIVADO_MEM)
print(f"copied -> {VIVADO_MEM}")
