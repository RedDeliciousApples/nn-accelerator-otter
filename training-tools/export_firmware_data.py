import hashlib
from pathlib import Path
from integer_network import IntegerNetwork

import numpy as np
import torch
from torchvision import datasets
from torchvision.transforms import v2

from models import HiddenLayer

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
    print(f"Digit {digit}: test image index {index}")

if (__name__ == "__main__"):
    selected += [index for _, index in select_edge_cases(images_int8, selected)]
    results = [run_once(i) for i in range(len(selected))]
    correct = sum(r["prediction"] == r["label"] for r in results)
    print(f"{correct}/{len(results)} predictions match their labels")
    find_float_integer_disagreements(images_int8, labels)
