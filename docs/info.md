<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
### SPI Peripheral
I implemented the SPI peripheral as a state machine with the follow states:
- IDLE: Whenever the peripheral is available to start a transaction it will be in this state
- RECV: The state the SPI peripheral enters after the IDLE state when its nCS port is set to 0. It remains in this state as it receives bits.
- FINISH: After the 16 bits of the transaction have been sent, the peripheral enters this state to update the specified register.

### PWM tests
I implemented tests to validate PWM frequency, and various duty cycles (0%, 50%, 100%). For the frequency test, I simply noted down the current time for two consecutive rising edges, the difference of which would be the period. I then took the reciprocal of the period and asserted that its within the listed 1% tolerance.

For the duty cycle test, I split it into 3 separate tests, one per configured duty cycle. Starting with 50%, we already know that the PWM device outputs at a frequency of 3 kHz, giving us the period as well. Then, I stored the time for a rising edge, and the subsequent falling edge. Finally, I took the difference between these times and asserted that it's within 1% of a half PWM period.

I could not use the same technique for the 0% and 100% tests as there would be no rising or falling edges. Instead, I noted down an initial time, and kept sampling the output until an entire PWM period has passed. For 0% duty cycle, if the output was ever not 0 the test would fail. For 100% duty cycle, if the output was ever not 1 the test would fail.
