// Software baseline for the network, see BOARD_FORMAT.md
// The data is already in memory (otter_data.mem), so this only reads it through pointers
#include <stdint.h>

#define OUT_SIZE 10

#define SCORES ((volatile int32_t *)0xA800)  // [10]

// Basys3 output ports (see Exp6_OTTER_Wrapper)
#define LEDS   (*(volatile uint32_t *)0x1100C000)
#define SEGS   (*(volatile uint32_t *)0x1100C004)
#define ANODES (*(volatile uint32_t *)0x1100C008)

#define CTRL   (*(volatile uint32_t *)0x11010000)  // write bit0 = 1 to start
#define STATUS (*(volatile uint32_t *)0x11010004)  // bit0 = busy, bit1 = done

// 7-segment patterns for 0-9: bit7 = a ... bit1 = g, bit0 = dp, active low
static const uint8_t SEG_DIGIT[10] = {
    0x03, 0x9F, 0x25, 0x0D, 0x99, 0x49, 0x41, 0x1F, 0x01, 0x09
};

int main(void) {
    //handshake
    CTRL = 1;                          // start (bit0)
    while ((STATUS & 2u) == 0) { }     // spin until done (bit1)
    // now SCORES are valid

    int32_t best = 0;  // argmax over the scores
    for (int k = 1; k < OUT_SIZE; k++)
        if (SCORES[k] > SCORES[best]) best = k;

    LEDS = 1u << best;             // one-hot LED, plus the digit on the rightmost 7-seg
    SEGS = SEG_DIGIT[best];
    ANODES = 0xE;                  // active low: enable only the rightmost digit

    for (;;) {}  // done; scores are at 0xA800
}
