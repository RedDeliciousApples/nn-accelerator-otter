from pathlib import Path

import numpy as np
import torch
from torchvision import datasets
from torchvision.transforms import v2

from integer_network import IntegerNetwork
from models import HiddenLayer


HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"
FLOAT_MODEL_PATH = ARTIFACTS_DIR / "model_hidden.pth"
INTEGER_WEIGHTS_PATH = ARTIFACTS_DIR / "mnist_integer_weights.pth"


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
    labels = torch.tensor([label for _, label in test_data])
    return images, labels


def load_integer_network():
    data = torch.load(INTEGER_WEIGHTS_PATH, map_location="cpu", weights_only=True)
    return IntegerNetwork(
        hidden_weights=data["hidden_weights"].numpy(),
        hidden_biases=data["hidden_biases"].numpy(),
        output_weights=data["output_weights"].numpy(),
        output_biases=data["output_biases"].numpy(),
        hidden_shift=int(data["hidden_shift"].item()),
    )


def float_predictions(images):
    model = HiddenLayer()
    model.load_state_dict(
        torch.load(FLOAT_MODEL_PATH, map_location="cpu", weights_only=True)
    )
    model.eval()
    with torch.no_grad():
        return model(images).argmax(dim=1).numpy()


def integer_predictions(network, images):
    # same pixel conversion as get_one_image.py / export_integer_weights.py
    pixels_int8 = (images * 127).round().to(torch.int8).numpy()
    return np.array([
        network.forward(pixels)["prediction"] for pixels in pixels_int8
    ])


def main():
    images, labels = load_test_set()
    labels = labels.numpy()

    float_pred = float_predictions(images)
    int_pred = integer_predictions(load_integer_network(), images)

    total = len(labels)
    float_correct = int((float_pred == labels).sum())
    int_correct = int((int_pred == labels).sum())
    agree = int((float_pred == int_pred).sum())

    print(f"Test images:        {total}")
    print(f"Float accuracy:     {float_correct / total * 100:.2f}% ({float_correct}/{total})")
    print(f"Integer accuracy:   {int_correct / total * 100:.2f}% ({int_correct}/{total})")
    print(f"Float/int agreement: {agree / total * 100:.2f}% ({agree}/{total})")

    print("\nPer-digit integer accuracy:")
    for digit in range(10):
        mask = labels == digit
        correct = int((int_pred[mask] == digit).sum())
        print(f"  {digit}: {correct / mask.sum() * 100:.2f}% ({correct}/{int(mask.sum())})")


if __name__ == "__main__":
    main()
