from pathlib import Path

import numpy as np
import torch
from torchvision import datasets
from torchvision.transforms import v2

from integer_network import IntegerNetwork


HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"
FLOAT_MODEL_PATH = ARTIFACTS_DIR / "model_hidden.pth"
OUTPUT_PATH = ARTIFACTS_DIR / "mnist_integer_weights.pth"
INPUT_SCALE = 1.0 / 127.0
CALIBRATION_SAMPLES = 1000


def quantize_weights(weights):
    scale = weights.abs().max().item() / 127.0
    if scale == 0:
        scale = 1.0
    quantized = torch.clamp(torch.round(weights / scale), -127, 127)
    return quantized.to(torch.int8), scale


def choose_hidden_shift(hidden_weights, hidden_biases):
    transform = v2.Compose([
        v2.ToImage(),
        v2.ToDtype(torch.float32, scale=True),
    ])
    calibration_data = datasets.MNIST(
        root=HERE / "data",
        train=True,
        download=True,
        transform=transform,
    )

    pixels = torch.stack([
        calibration_data[index][0].reshape(784)
        for index in range(CALIBRATION_SAMPLES)
    ])
    pixels_int8 = torch.round(pixels * 127).to(torch.int32)
    sums = pixels_int8 @ hidden_weights.to(torch.int32).T
    sums += hidden_biases.to(torch.int32)
    largest_sum = int(torch.clamp(sums, min=0).max().item())

    shift = 0
    while largest_sum > 127:
        largest_sum >>= 1
        shift += 1
    return shift


def main():
    ARTIFACTS_DIR.mkdir(exist_ok=True)
    state_dict = torch.load(
        FLOAT_MODEL_PATH,
        map_location="cpu",
        weights_only=True,
    )

    hidden_float = state_dict["network.0.weight"]
    hidden_bias_float = state_dict["network.0.bias"]
    output_float = state_dict["network.2.weight"]
    output_bias_float = state_dict["network.2.bias"]

    hidden_weights, hidden_weight_scale = quantize_weights(hidden_float)
    output_weights, output_weight_scale = quantize_weights(output_float)

    hidden_biases = torch.round(
        hidden_bias_float / (INPUT_SCALE * hidden_weight_scale)
    ).to(torch.int32)

    hidden_shift = choose_hidden_shift(hidden_weights, hidden_biases)
    hidden_scale = INPUT_SCALE * hidden_weight_scale * (2 ** hidden_shift)

    output_biases = torch.round(
        output_bias_float / (hidden_scale * output_weight_scale)
    ).to(torch.int32)

    torch.save(
        {
            "hidden_weights": hidden_weights,
            "hidden_biases": hidden_biases,
            "output_weights": output_weights,
            "output_biases": output_biases,
            "hidden_shift": torch.tensor(hidden_shift, dtype=torch.int32),
            "input_scale": torch.tensor(INPUT_SCALE),
            "hidden_weight_scale": torch.tensor(hidden_weight_scale),
            "output_weight_scale": torch.tensor(output_weight_scale),
        },
        OUTPUT_PATH,
    )

    network = IntegerNetwork(
        hidden_weights.numpy(),
        hidden_biases.numpy(),
        output_weights.numpy(),
        output_biases.numpy(),
        hidden_shift,
    )
    print("Saved:", OUTPUT_PATH)
    print("Hidden shift:", hidden_shift)
    print("Hidden weight shape:", tuple(hidden_weights.shape))
    print("Output weight shape:", tuple(output_weights.shape))
    print("Integer network ready:", network is not None)


if __name__ == "__main__":
    main()
