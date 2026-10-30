from pathlib import Path

import numpy as np
import torch
import integer_network
import get_one_image


HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"

def to_numpy(value):
    if isinstance(value, torch.Tensor):
        return value.detach().cpu().numpy()
    return np.asarray(value)


filename = get_one_image.get_one_image()

print("Loading image from:", filename)

weights_filename = input(
    "Enter filename of the weights file to load "
        "(e.g., mnist_integer_weights.pth): "
).strip()
weights_path = ARTIFACTS_DIR / Path(weights_filename).name
print("Loading weights from:", weights_path)


image_data = torch.load(Path(filename), map_location="cpu", weights_only=True)

if "pixels_int8" not in image_data:
    raise KeyError("The image file must contain a 'pixels_int8' entry.")

image = to_numpy(image_data["pixels_int8"]).reshape(-1)
if image.size != 784:
    raise ValueError(f"Expected 784 image pixels, but found {image.size}.")

weight_data = torch.load(
    weights_path,
    map_location="cpu",
    weights_only=True,
)

network = integer_network.IntegerNetwork(
    hidden_weights=to_numpy(weight_data["hidden_weights"]),
    hidden_biases=to_numpy(weight_data["hidden_biases"]),
    output_weights=to_numpy(weight_data["output_weights"]),
    output_biases=to_numpy(weight_data["output_biases"]),
    hidden_shift=int(to_numpy(weight_data["hidden_shift"]).item())
)

result = network.forward(image)
prediction = result["prediction"]
print("Predicted digit:", prediction)

if "correct_digit" in image_data:
    correct_digit = int(image_data["correct_digit"])
    print("Correct digit:", correct_digit)
    print("Correct prediction:", prediction == correct_digit)

print("Output scores:", result["output_sums"])
