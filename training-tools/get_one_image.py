from pathlib import Path

import torch
import random
from torchvision import datasets
from torchvision.transforms import v2


HERE = Path(__file__).resolve().parent
IMAGE_DIR = HERE / "artifacts" / "images"


def get_one_image():
    filename = input("Getting a random image from the MNIST test set. Enter filename to save image (e.g. 'image.pth'): ").strip()
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    image_path = IMAGE_DIR / Path(filename).name

    transform = v2.Compose([
        v2.ToImage(),
        v2.ToDtype(torch.float32, scale=True)
    ])

    test_data = datasets.MNIST(
        root="data",
        train=False,
        download=True,
        transform=transform
    )

    image_number = random.randint(0, len(test_data) - 1)

    image, correct_digit = test_data[image_number]

    pixels = image.reshape(784)

    pixels_int8 = (pixels * 127).round().to(torch.int8)


    print("Correct digit:", correct_digit)
    print("Image shape:", image.shape)

    torch.save(
        {
            "image_number": image_number,
            "correct_digit": correct_digit,
            "pixels_int8": pixels_int8
        },
        image_path
    )

    print("Image saved to " + str(image_path))

    return image_path
