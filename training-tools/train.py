import os
import torch
import copy
from torch import nn
from torchao.quantization import Int8WeightOnlyConfig, quantize_
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torchvision.transforms import v2
from settings import BATCH_SIZE, device, SEED, EPOCHS, LEARNING_RATE
from models import *


def train(dataloader, model, loss_fn, optimizer):
    model.train()

    total_loss = 0

    for X, y in dataloader:

        X = X.to(device)
        y = y.to(device)

        optimizer.zero_grad()

        pred = model(X)

        loss = loss_fn(pred, y)

        loss.backward()
        optimizer.step()

        total_loss += loss.item()

    average_loss = total_loss / len(dataloader)

    return average_loss



training_data = datasets.MNIST(
    root="data",
    train=True,
    download=True,
    transform=v2.Compose([
        v2.ToImage(),
        v2.ToDtype(torch.float32, scale=True)
    ])
)

test_data = datasets.MNIST(
    root="data",
    train=False,
    download=True,
    transform=v2.Compose([
        v2.ToImage(),
        v2.ToDtype(torch.float32, scale=True)
    ])
)

def make_dataloader():
    generator = torch.Generator()
    generator.manual_seed(SEED)

    return DataLoader(
        training_data,
        batch_size=BATCH_SIZE,
        shuffle=True,
        generator=generator
    )

dataloader1 = make_dataloader()
dataloader2 = make_dataloader()


device = torch.accelerator.current_accelerator().type if torch.accelerator.is_available() else "cpu"
print("using device:" + device)



torch.manual_seed(SEED)
model_no_hidden = NoHiddenLayers().to(device)

torch.manual_seed(SEED)
model_hidden = HiddenLayer().to(device)

loss_fn = nn.CrossEntropyLoss()

optimizer = torch.optim.SGD(
    model_no_hidden.parameters(),
    lr=LEARNING_RATE
)

optimizer2 = torch.optim.SGD(
    model_hidden.parameters(),
    lr=LEARNING_RATE
)


def train(dataloader, model, loss_fn, optimizer):
    model.train()

    total_loss = 0

    for X, y in dataloader:

        X = X.to(device)
        y = y.to(device)

        optimizer.zero_grad()

        pred = model(X)

        loss = loss_fn(pred, y)

        loss.backward()
        optimizer.step()

        total_loss += loss.item()

    average_loss = total_loss / len(dataloader)

    return average_loss


print("\nTraining model with no hidden layer: 784 -> 10\n")


for epoch in range(EPOCHS):
    loss = train(dataloader1, model_no_hidden, loss_fn, optimizer)
    print(f"Epoch {epoch + 1} / {EPOCHS}"
          f"\tLoss: {loss:.4f}"
    )

print("\nTraining model with hidden layer: 784 -> 32 -> 10\n")

for epoch in range(EPOCHS):
    loss = train(dataloader2, model_hidden, loss_fn, optimizer2)
    print(f"Epoch {epoch + 1} / {EPOCHS}"
          f"\tLoss: {loss:.4f}"
    )


print("\n-------------------------------")
print("DONE TRAINING")
print("-------------------------------")





# torch.save(
#     model_hidden.state_dict(),
#     "model_hidden.pth"
# )

# print("Saved model_hidden.pth")