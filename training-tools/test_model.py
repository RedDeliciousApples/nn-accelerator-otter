import os
import torch
import copy
from torch import nn
from torchao.quantization import Int8WeightOnlyConfig, quantize_
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torchvision.transforms import v2
from models import HiddenLayer
from settings import BATCH_SIZE,  device

print("Using:", device)


model = HiddenLayer().to(device)

quantize_(
    model,
    Int8WeightOnlyConfig()
)

checkpoint = torch.load(
    "model_hidden_int4_torchao.pth",
    map_location=device,
    weights_only=True
)

model.load_state_dict(
    checkpoint["model_state_dict"]
)

model.eval()


test_data = datasets.MNIST(
    root="data",
    train=False,
    download=True,
    transform=v2.Compose([
        v2.ToImage(),
        v2.ToDtype(torch.float32, scale=True)
    ])
)

test_dataloader = DataLoader(
    test_data,
    batch_size = BATCH_SIZE,
    shuffle = False
)



def test(dataloader,model):

    model.eval()

    correct = 0
    total = 0

    #no need for gradients when testing
    with torch.no_grad():
        for X, y in dataloader:

            X = X.to(device)
            y = y.to(device)

            pred = model(X)

           
            predicted_digits = pred.argmax(dim=1)


            correct += (predicted_digits == y).sum().item()

            total += y.size(0)

    accuracy = correct / total

    return accuracy

accuracy = test(test_dataloader, model)

print(
    f"Quantized accuracy: "
    f"{accuracy * 100:.2f}%"
)