import torch
from torch import nn
from torchao.quantization import quantize_, Int4WeightOnlyConfig
from models import HiddenLayer
from settings import device

print("Using:", device)


model = HiddenLayer().to(device)

weights = torch.load(
    "model_hidden.pth",
    map_location=device,
    weights_only=True
)

model.load_state_dict(weights)
model.eval()

quantize_(model, Int4WeightOnlyConfig())

torch.save(
    {
        "model_state_dict": model.state_dict(),
        "model_type": "784-32-10",
        "quantization": "Int4WeightOnlyConfig"
    },
    "model_hidden_int4_torchao.pth"
)

print("Saved quantized model")