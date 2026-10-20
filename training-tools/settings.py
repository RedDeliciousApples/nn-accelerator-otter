import torch

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
SEED = 42
EPOCHS = 5
BATCH_SIZE = 64
LEARNING_RATE = 0.01
