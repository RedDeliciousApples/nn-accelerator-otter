// Software baseline for the network, see BOARD_FORMAT.md
// The data is already in memory (otter_data.mem), so this only reads it through pointers
#include <stdint.h>

#define IN_SIZE 784
#define HIDDEN_SIZE 32
#define OUT_SIZE 10

#define HIDDEN_W ((const int8_t *)0x4000)    // [32][784]
#define HIDDEN_B ((const int32_t *)0xA200)   // [32]
#define OUTPUT_W ((const int8_t *)0xA280)    // [10][32]
#define OUTPUT_B ((const int32_t *)0xA3C0)   // [10]
#define HIDDEN_SHIFT (*(const volatile int32_t *)0xA3E8)
#define IMAGE ((const int8_t *)0xA400)       // [784]
#define SCORES ((volatile int32_t *)0xA800)  // [10]

int main(void) {
    int32_t hidden[HIDDEN_SIZE];
    int32_t shift = HIDDEN_SHIFT;

    for (int n = 0; n < HIDDEN_SIZE; n++) {
        const int8_t *row = HIDDEN_W + n * IN_SIZE;
        int32_t sum = HIDDEN_B[n];
        for (int i = 0; i < IN_SIZE; i++)
            sum += row[i] * IMAGE[i];
        sum >>= shift;  // arithmetic shift on signed int, because it's quantized
        hidden[n] = sum < 0 ? 0 : (sum > 127 ? 127 : sum); //clamp to [0, 127] for ReLU
    }

    for (int k = 0; k < OUT_SIZE; k++) {
        const int8_t *row = OUTPUT_W + k * HIDDEN_SIZE;
        int32_t sum = OUTPUT_B[k];
        for (int j = 0; j < HIDDEN_SIZE; j++)
            sum += row[j] * hidden[j];
        SCORES[k] = sum;
    }

    for (;;) {}  // done; scores are at 0xA800
}
