"""
usage: python training-tools/show_test_images.py [start] [count] [-o out.png] [--cols N]
Defaults to images 0-59, and output goes to artifacts/images/mnist_test_<start>-<end>.png.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw
from torchvision import datasets

HERE = Path(__file__).resolve().parent
CELL_W, CELL_H, SCALE = 84, 100, 2

parser = argparse.ArgumentParser()
parser.add_argument("start", nargs="?", type=int, default=0)
parser.add_argument("count", nargs="?", type=int, default=60)
parser.add_argument("-o", "--out", type=Path)
parser.add_argument("--cols", type=int, default=10)
args = parser.parse_args()

data = datasets.MNIST(root=HERE / "data", train=False, download=True)
labels = [int(label) for label in data.targets]
end = min(args.start + args.count, len(labels))
assert 0 <= args.start < end, "start out of range"
firsts = {labels.index(d) for d in range(10)}

rows = -(-(end - args.start) // args.cols)
sheet = Image.new("RGB", (args.cols * CELL_W, rows * CELL_H), "white")
draw = ImageDraw.Draw(sheet)
for n, i in enumerate(range(args.start, end)):
    x, y = (n % args.cols) * CELL_W, (n // args.cols) * CELL_H
    picked = i in firsts
    if picked:
        draw.rectangle([x + 2, y + 2, x + CELL_W - 3, y + CELL_H - 3], outline="red", width=2)
    thumb = Image.fromarray(data.data[i].numpy()).resize((28 * SCALE, 28 * SCALE), Image.NEAREST)
    sheet.paste(thumb.convert("RGB"), (x + 14, y + 6))
    draw.text((x + 8, y + 68), f"idx {i}", fill="black")
    draw.text((x + 8, y + 82), f"label {labels[i]}" + (" *" if picked else ""), fill="red" if picked else "black")

out = args.out or HERE / "artifacts" / "images" / f"mnist_test_{args.start}-{end - 1}.png"
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"saved {out}")
