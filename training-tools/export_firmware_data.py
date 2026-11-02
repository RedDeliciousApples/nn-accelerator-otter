import hashlib
from pathlib import Path
from integer_network import IntegerNetwork

import numpy as np
import torch
from torchvision import datasets
from torchvision.transforms import v2

from models import HiddenLayer
import board_layout

HERE = Path(__file__).resolve().parent

path = HERE / "artifacts" / "mnist_integer_weights.pth"
float_model_path = HERE / "artifacts" / "model_hidden.pth"


my_dict = torch.load(path, map_location="cpu", weights_only=True)

for key, value in my_dict.items():
    if key != "hidden_shift":
        print(f"Name: {key}, Shape: {value.shape}, Dtype: {value.dtype}")
    else:
        print(f"Name: {key}, Shape: {value.shape}, Dtype: {value.dtype}, Hidden shift: {int(my_dict['hidden_shift'].item())}")


with open(path, "rb") as f:
    data = f.read()
    hash = hashlib.sha256(data).hexdigest()
    print(f"SHA256 Hash: {hash}")


#IntegerNetwork(hidden_weights, hidden_biases, output_weights, output_biases, hidden_shift)
net = IntegerNetwork(my_dict["hidden_weights"].numpy(), my_dict["hidden_biases"].numpy(), my_dict["output_weights"].numpy(), my_dict["output_biases"].numpy(), int(my_dict["hidden_shift"].item()))


def run_once(position):
    # position is 0-9: which entry of the selected list to run
    index = selected[position]
    result = net.forward(images_int8[index].numpy())
    label = labels[index].item()
    print(f"Image {position} (test image {index}): predicted {result['prediction']}, actual {label}")
    return {"index": index, "label": label, **result}

def load_test_set():
    transform = v2.Compose([
        v2.ToImage(),
        v2.ToDtype(torch.float32, scale=True),
    ])
    test_data = datasets.MNIST(
        root=HERE / "data",
        train=False,
        download=True,
        transform=transform,
    )
    images = torch.stack([image.reshape(784) for image, _ in test_data])
    images_int8 = (images * 127).round().to(torch.int8)
    labels = torch.tensor([label for _, label in test_data])
    print(images_int8.shape, images_int8.dtype, images_int8.min().item(), images_int8.max().item())
    return images_int8, labels


def select_images(labels):
    # first test image of each digit 0-9, so the choice is the same every run
    labels_list = labels.tolist()
    return [labels_list.index(digit) for digit in range(10)]


def select_edge_cases(images_int8, already_selected):
    # images that stress the arithmetic: saturation, negative sums, near-tied scores
    clamped = []
    most_negative = []
    margin = []
    for index in range(len(images_int8)):
        result = net.forward(images_int8[index].numpy())
        top_two = np.partition(result["output_sums"], -2)[-2:]
        clamped.append(int((result["hidden"] == 127).sum()))
        most_negative.append(int(result["hidden_sums"].min()))
        margin.append(int(top_two[1] - top_two[0]))

    criteria = [
        ("most hidden neurons clamped at 127", clamped, True),
        ("most negative hidden sum", most_negative, False),
        ("smallest gap between top two scores", margin, False),
    ]
    edge_cases = []
    taken = set(already_selected)
    for reason, values, largest_first in criteria:
        # stable sort, so ties go to the lowest image index
        ranked = sorted(range(len(values)), key=lambda i: values[i], reverse=largest_first)
        index = next(i for i in ranked if i not in taken)
        taken.add(index)
        edge_cases.append((reason, index))
        print(f"Edge case ({reason}): test image {index}, value {values[index]}")
    return edge_cases


def find_float_integer_disagreements(images_int8, labels):
    model = HiddenLayer()
    model.load_state_dict(
        torch.load(float_model_path, map_location="cpu", weights_only=True)
    )
    model.eval()

    with torch.no_grad():
        float_outputs = model(images_int8.float() / 127).numpy()

    disagreements = []
    for index, float_output in enumerate(float_outputs):
        integer_result = net.forward(images_int8[index].numpy())
        float_prediction = int(float_output.argmax())
        integer_prediction = integer_result["prediction"]
        if float_prediction == integer_prediction:
            continue

        top_two = torch.topk(torch.from_numpy(float_output), 2).values
        disagreements.append({
            "index": index,
            "label": labels[index].item(),
            "float_prediction": float_prediction,
            "integer_prediction": integer_prediction,
            "float_margin": (top_two[0] - top_two[1]).item(),
            "integer_margin": int(np.partition(
                integer_result["output_sums"], -2
            )[-1] - np.partition(integer_result["output_sums"], -2)[-2]),
        })

    print(f"\nFloat/integer disagreements: {len(disagreements)}")
    for disagreement in disagreements:
        print(
            "  "
            f"test image {disagreement['index']}: "
            f"label {disagreement['label']}, "
            f"float {disagreement['float_prediction']} "
            f"(margin {disagreement['float_margin']:.6f}), "
            f"integer {disagreement['integer_prediction']} "
            f"(margin {disagreement['integer_margin']})"
        )


images_int8, labels = load_test_set()
selected = select_images(labels)

for digit, index in enumerate(selected):
    assert labels[index].item() == digit
    print(f"Image {digit}: test image index {index}")

# Convert a byte array to a string of hex values, 16 per line: four spaces, .byte, then the numbers joined with ", ".
def bytes_to_text(byte_array):
    # flatten the array and convert to a list of integers
    byte_array = byte_array.flatten().tolist()
    lines = []
    for i in range(0, len(byte_array), 16):
        line = "    .byte " + ", ".join(f"{b}" for b in byte_array[i:i+16])
        lines.append(line)
    return "\n".join(lines)

# Convert an int32 array to .word lines, 8 per line.
def words_to_text(word_array):
    word_array = word_array.flatten().tolist()
    lines = []
    for i in range(0, len(word_array), 8):
        lines.append("    .word " + ", ".join(f"{w}" for w in word_array[i:i+8]))
    return "\n".join(lines)


def region_bytes(name, array):
    # pack an array into the little-endian bytes the layout expects, checking dtype and size
    dtype = {1: np.int8, 4: np.int32}[board_layout.REGIONS[name][2]]
    array = np.asarray(array)
    assert array.size * dtype().itemsize == board_layout.size(name), f"{name}: wrong element count {array.size}"
    assert array.min() >= np.iinfo(dtype).min and array.max() <= np.iinfo(dtype).max, f"{name}: value out of range"
    return array.astype(np.dtype(dtype).newbyteorder("<")).tobytes()


def region_arrays(weights, image_int8):
    # the regions that carry data (SCORES is output only), as numpy arrays
    to_numpy = lambda x: x.numpy() if hasattr(x, "numpy") else np.asarray(x)
    return {
        "HIDDEN_W": to_numpy(weights["hidden_weights"]),
        "HIDDEN_B": to_numpy(weights["hidden_biases"]),
        "OUTPUT_W": to_numpy(weights["output_weights"]),
        "OUTPUT_B": to_numpy(weights["output_biases"]),
        "HIDDEN_SHIFT": np.array([int(weights["hidden_shift"])], dtype=np.int32),
        "IMAGE": to_numpy(image_int8),
    }


def build_memory_image(weights, image_int8):
    # 64 KB data image, every region absolute address, code area is 0
    memory = bytearray(board_layout.MEM_SIZE)
    for name, array in region_arrays(weights, image_int8).items():
        address = board_layout.addr(name)
        data = region_bytes(name, array)
        memory[address:address + len(data)] = data
    return memory


def build_assembly(weights, image_int8, image_note=""):
    # .data section to link at HIDDEN_W, labels and .space padding reproduce the absolute layout
    regions = sorted(board_layout.REGIONS.items(), key=lambda r: r[1][0])
    arrays = region_arrays(weights, image_int8)
    lines = [
        "# Generated by export_firmware_data.py; see BOARD_FORMAT.md",
        f"# Link this .data section at 0x{board_layout.addr('HIDDEN_W'):04X}",
    ]
    if image_note:
        lines.append(f"# {image_note}")
    lines += [f".eqv {name}_ADDR 0x{address:04X}" for name, (address, _, _) in regions]
    lines += ["", ".data", ".align 2"]

    position = board_layout.addr("HIDDEN_W")
    for name, (address, length, width) in regions:
        if address > position:
            lines.append(f"    .space {address - position}")
        lines.append(f"{name.lower()}:")
        if name in arrays:
            region_bytes(name, arrays[name])  # validate dtype, size and range
            lines.append(bytes_to_text(arrays[name]) if width == 1 else words_to_text(arrays[name]))
        else:
            lines.append(f"    .space {length}")
        position = address + length
    return "\n".join(lines) + "\n"


def write_mem_file(memory, path):
    # $readmemh format: one 32-bit word per line, as in otter_memory.mem
    with open(path, "w") as f:
        for i in range(0, len(memory), 4):
            f.write(f"{int.from_bytes(memory[i:i+4], 'little'):08x}\n")


def read_region(memory, name, dtype):
    address, length, _ = board_layout.REGIONS[name]
    return np.frombuffer(bytes(memory[address:address + length]), dtype=np.dtype(dtype).newbyteorder("<"))


def verify_memory_image(memory, image_int8):
    # decode the image from raw bytes only, then compare with the reference network
    decoded = IntegerNetwork(
        read_region(memory, "HIDDEN_W", np.int8).reshape(board_layout.HIDDEN_SIZE, board_layout.IN_SIZE),
        read_region(memory, "HIDDEN_B", np.int32),
        read_region(memory, "OUTPUT_W", np.int8).reshape(board_layout.OUT_SIZE, board_layout.HIDDEN_SIZE),
        read_region(memory, "OUTPUT_B", np.int32),
        int(read_region(memory, "HIDDEN_SHIFT", np.int32)[0]),
    )
    from_memory = decoded.forward(read_region(memory, "IMAGE", np.int8))
    reference = net.forward(image_int8)
    assert np.array_equal(from_memory["output_sums"], reference["output_sums"]), "memory image does not reproduce the reference scores"
    return from_memory


def export_all(position=0, out_dir=HERE / "artifacts" / "firmware"):
    # write network_data.s and otter_data.mem for the selected digit image, after a round-trip check
    index = selected[position]
    image = images_int8[index].numpy()
    memory = build_memory_image(my_dict, image)
    result = verify_memory_image(memory, image)
    out_dir.mkdir(parents=True, exist_ok=True)
    note = f"image: test image {index}, label {labels[index].item()}, expected scores {result['output_sums'].tolist()}"
    (out_dir / "network_data.s").write_text(build_assembly(my_dict, image, note))
    write_mem_file(memory, out_dir / "otter_data.mem")
    print(f"Exported test image {index} (label {labels[index].item()}), prediction {result['prediction']}, to {out_dir}")
    return result


if (__name__ == "__main__"):
    # selected += [index for _, index in select_edge_cases(images_int8, selected)]
    # results = [run_once(i) for i in range(len(selected))]
    # correct = sum(r["prediction"] == r["label"] for r in results)
    # print(f"{correct}/{len(results)} predictions match their labels")
    # find_float_integer_disagreements(images_int8, labels)
    import sys
    # usage: python export_firmware_data.py [digit 0-9]
    export_all(int(sys.argv[1]) if len(sys.argv) > 1 else 0)
