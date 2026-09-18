import torch
import copy
from torch import nn
from torchao.quantization import Int8WeightOnlyConfig, quantize_
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torchvision.transforms import v2

class NoHiddenLayers(nn.Module):

    def __init__(self):
        super().__init__()

        self.flatten = nn.Flatten()
        self.network = nn.Linear(784, 10)

    def forward(self, x):
        x = self.flatten(x)
        x = self.network(x)
        return x


class HiddenLayer(nn.Module):
    def __init__(self):
        super().__init__()

        self.flatten = nn.Flatten()

        self.network = nn.Sequential(
            nn.Linear(784, 32),
            nn.ReLU(),
            nn.Linear(32, 10)
        )

    def forward(self, x):
        x = self.flatten(x)
        x = self.network(x)
        return x
