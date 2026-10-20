import numpy as np


class IntegerNetwork:
    def __init__(
        self,
        hidden_weights,
        hidden_biases,
        output_weights,
        output_biases,
        hidden_shift
    ):
        self.hidden_weights = hidden_weights.astype(np.int8)
        self.hidden_biases = hidden_biases.astype(np.int32)

        self.output_weights = output_weights.astype(np.int8)
        self.output_biases = output_biases.astype(np.int32)

        self.hidden_shift = hidden_shift

    def forward(self, image):
        # image shape: [784]
        image = image.astype(np.int32)

        # First layer: 784 -> 32
        # note: the @ is matrix mult
        hidden_sums = (
            self.hidden_weights.astype(np.int32) @ image
            + self.hidden_biases
        )

        # reduce result to int8 with a right shift (divide by 2^hidden_shift)
        hidden = hidden_sums >> self.hidden_shift

        # ReLU and clamp to 0–127
        hidden = np.clip(hidden, 0, 127).astype(np.int8)

        # Second layer: 32 -> 10
        output_sums = (
            self.output_weights.astype(np.int32)
            @ hidden.astype(np.int32)
            + self.output_biases
        )

        prediction = int(np.argmax(output_sums))

        return {
            "hidden_sums": hidden_sums,
            "hidden": hidden,
            "output_sums": output_sums,
            "prediction": prediction,
        }