from torch import nn


class NoHiddenLayers(nn.Module):
    def __init__(self):
        super().__init__()
        self.flatten = nn.Flatten()
        self.network = nn.Linear(784, 10)

    def forward(self, x):
        return self.network(self.flatten(x))


class HiddenLayer(nn.Module):
    def __init__(self):
        super().__init__()
        self.flatten = nn.Flatten()
        self.network = nn.Sequential(
            nn.Linear(784, 32),
            nn.ReLU(),
            nn.Linear(32, 10),
        )

    def forward(self, x):
        return self.network(self.flatten(x))
