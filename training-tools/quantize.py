from pathlib import Path

import torch
from torchao.quantization import Int8WeightOnlyConfig, quantize_

from models import HiddenLayer
from settings import device
from test_model import make_test_dataloader, test


HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"
FLOAT_MODEL_PATH = ARTIFACTS_DIR / "model_hidden.pth"
QUANTIZED_MODEL_PATH = ARTIFACTS_DIR / "model_hidden_int8_torchao.pth"


def main():
    print("Using:", device)
    ARTIFACTS_DIR.mkdir(exist_ok=True)

    model = HiddenLayer().to(device)
    weights = torch.load(
        FLOAT_MODEL_PATH,
        map_location=device,
        weights_only=True,
    )
    model.load_state_dict(weights)
    model.eval()

    test_dataloader = make_test_dataloader()
    float_accuracy = test(test_dataloader, model)

    quantize_(model, Int8WeightOnlyConfig())
    int8_accuracy = test(test_dataloader, model)

    torch.save(
        {
            "model_state_dict": model.state_dict(),
            "model_type": "784-32-10",
            "quantization": "Int8WeightOnlyConfig",
            "test_accuracy": int8_accuracy,
        },
        QUANTIZED_MODEL_PATH,
    )

    print(f"Float accuracy: {float_accuracy * 100:.2f}%")
    print(f"INT8 accuracy: {int8_accuracy * 100:.2f}%")
    print("Saved:", QUANTIZED_MODEL_PATH)


if __name__ == "__main__":
    main()
