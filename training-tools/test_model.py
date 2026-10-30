from pathlib import Path

import torch
from torch.utils.data import DataLoader
from torchao.quantization import Int8WeightOnlyConfig, quantize_
from torchvision import datasets
from torchvision.transforms import v2

from models import HiddenLayer
from settings import BATCH_SIZE, device


HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"
QUANTIZED_MODEL_PATH = ARTIFACTS_DIR / "model_hidden_int8_torchao.pth"

transform = v2.Compose([
    v2.ToImage(),
    v2.ToDtype(torch.float32, scale=True),
])


def make_test_dataloader():
    test_data = datasets.MNIST(
        root=HERE / "data",
        train=False,
        download=True,
        transform=transform,
    )
    return DataLoader(test_data, batch_size=BATCH_SIZE, shuffle=False)


def test(dataloader, model):
    model.eval()
    correct = 0
    total = 0

    with torch.no_grad():
        for images, labels in dataloader:
            images = images.to(device)
            labels = labels.to(device)
            predictions = model(images).argmax(dim=1)
            correct += (predictions == labels).sum().item()
            total += labels.size(0)

    return correct / total


def load_quantized_model():
    model = HiddenLayer().to(device)
    quantize_(model, Int8WeightOnlyConfig())
    checkpoint = torch.load(
        QUANTIZED_MODEL_PATH,
        map_location=device,
        weights_only=True,
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    return model


def main():
    print("Using:", device)
    model = load_quantized_model()
    accuracy = test(make_test_dataloader(), model)
    print(f"INT8 accuracy: {accuracy * 100:.2f}%")


if __name__ == "__main__":
    main()
