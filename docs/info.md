<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
SPI Peripheral:
- The slave device in the SPI protocol
- We're gonna configure it so that when it receives valid inputs from the controller (master), it'll conigure the specified registers with the specified values
- In more detail: On every rising edge of SCLK (ui_in\[0\]), we sample a value from COPI (ui_in\[1\]) so long as the condition on nCS (ui_in\[2\] = '0') passes. 
- We determine if we're on the rising edge by storing the 2 most recent SCLK values, if they are in a way such that a rising edge is evident, we proceed with the sampling.
- Unlike I2C, there's no start or end phases, you simply de-assert nCS by setting it to 1. Our perpheral module need only look for this condition.
- When we're sampling data, again we do it on the rising edge, but that data gets shifted out on the falling edge. Our peripheral module is gonna have outputs of the data its receiving, so whatever is driven by this output is gonna maintaing its value until it gets shifted out at the falling edge of SCLK. 
## How to test
Explain how to use your project
placeholder text
## External hardware
List external hardware used in your project (e.g. PMOD, LED display, etc), if any
placeholder text
