from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader
from torchvision import datasets
from torchvision.transforms import v2

from models import HiddenLayer, NoHiddenLayers
from settings import BATCH_SIZE, EPOCHS, LEARNING_RATE, SEED, device
from test_model import make_test_dataloader, test


HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"
MODEL_PATH = ARTIFACTS_DIR / "model_hidden.pth"

transform = v2.Compose([
    v2.ToImage(),
    v2.ToDtype(torch.float32, scale=True),
])


def make_train_dataloader():
    training_data = datasets.MNIST(
        root=HERE / "data",
        train=True,
        download=True,
        transform=transform,
    )
    generator = torch.Generator().manual_seed(SEED)
    return DataLoader(
        training_data,
        batch_size=BATCH_SIZE,
        shuffle=True,
        generator=generator,
    )


def train_epoch(dataloader, model, loss_fn, optimizer):
    model.train()
    total_loss = 0.0

    for images, labels in dataloader:
        images = images.to(device)
        labels = labels.to(device)
        optimizer.zero_grad()
        loss = loss_fn(model(images), labels)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()

    return total_loss / len(dataloader)


def train_model(name, model, dataloader):
    loss_fn = nn.CrossEntropyLoss()
    optimizer = torch.optim.SGD(model.parameters(), lr=LEARNING_RATE)

    print(f"\nTraining {name}")
    for epoch in range(EPOCHS):
        loss = train_epoch(dataloader, model, loss_fn, optimizer)
        print(f"Epoch {epoch + 1}/{EPOCHS} - Loss: {loss:.4f}")


def main():
    print("Using:", device)
    ARTIFACTS_DIR.mkdir(exist_ok=True)

    torch.manual_seed(SEED)
    model_no_hidden = NoHiddenLayers().to(device)
    torch.manual_seed(SEED)
    model_hidden = HiddenLayer().to(device)

    train_model("784 -> 10", model_no_hidden, make_train_dataloader())
    train_model("784 -> 32 -> 10", model_hidden, make_train_dataloader())

    test_dataloader = make_test_dataloader()
    accuracy_no_hidden = test(test_dataloader, model_no_hidden)
    accuracy_hidden = test(test_dataloader, model_hidden)

    print("\nFinal results")
    print(f"784 -> 10 accuracy: {accuracy_no_hidden * 100:.2f}%")
    print(f"784 -> 32 -> 10 accuracy: {accuracy_hidden * 100:.2f}%")

    torch.save(model_hidden.state_dict(), MODEL_PATH)
    print("Saved:", MODEL_PATH)


if __name__ == "__main__":
    main()
