import os
import torch
import copy
from torch import nn
from torchao.quantization import Int8WeightOnlyConfig, quantize_
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torchvision.transforms import v2
from models import HiddenLayer, NoHiddenLayers
from test_model import test, test_dataloader
from settings import *
